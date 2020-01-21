{-# LANGUAGE DeriveAnyClass         #-}
{-# LANGUAGE DeriveGeneric          #-}
{-# LANGUAGE DuplicateRecordFields  #-}
{-# LANGUAGE FlexibleContexts       #-}
{-# LANGUAGE FlexibleInstances      #-}
{-# LANGUAGE FunctionalDependencies #-}
{-# LANGUAGE NamedFieldPuns         #-}
{-# LANGUAGE QuasiQuotes            #-}
{-# LANGUAGE RecordWildCards        #-}
{-# LANGUAGE ScopedTypeVariables    #-}
{-# LANGUAGE TemplateHaskell        #-}

module Environment.App where


-- * import


import           Control.Lens                     hiding (element)

import           Control.Lens                     (makeFieldsNoPrefix)
import           Control.Monad.Except             (MonadError)
import           Control.Monad.IO.Class           (MonadIO, liftIO)
import           Control.Monad.Reader             (MonadReader)
import           Data.Aeson                       (FromJSON, ToJSON (..),
                                                   defaultOptions,
                                                   fieldLabelModifier,
                                                   genericToJSON, parseJSON)
import           Data.Aeson.Types                 (genericParseJSON)
import           Data.Foldable                    (foldl')
import           Data.HashMap.Strict              as HashMap (HashMap, elems,
                                                              empty, insertWith)
import           Data.List                        (find)
import           Database.PostgreSQL.Simple       (Connection, FromRow,
                                                   Only (..), execute, query)
import           Database.PostgreSQL.Simple.SqlQQ
import           DB
import           GHC.Generics
import           PatchGirl
import           Prelude                          hiding (id)
import           Servant                          (err404, throwError)
import           Servant.Server                   (ServerError)
import           Session.Model


-- * get environments


data PGEnvironmentWithKeyValue =
  PGEnvironmentWithKeyValue { _environmentId   :: Int
                            , _environmentName :: String
                            , _keyValueId      :: Int
                            , _key             :: String
                            , _value           :: String
                            } deriving (Generic, FromRow)

data PGEnvironmentWithoutKeyValue =
  PGEnvironmentWithoutKeyValue { _environmentId   :: Int
                               , _environmentName :: String
                               } deriving (Generic, FromRow)


$(makeFieldsNoPrefix ''PGEnvironmentWithKeyValue)
$(makeFieldsNoPrefix ''PGEnvironmentWithoutKeyValue)

data KeyValue =
  KeyValue { _id    :: Int
           , _key   :: String
           , _value :: String
           } deriving (Eq, Show, Generic, FromRow)

instance ToJSON KeyValue where
  toJSON =
    genericToJSON defaultOptions { fieldLabelModifier = drop 1 }

$(makeFieldsNoPrefix ''KeyValue)

data Environment
  = Environment { _id        :: Int
                , _name      :: String
                , _keyValues :: [KeyValue]
                } deriving (Eq, Show, Generic)

instance ToJSON Environment where
  toJSON =
    genericToJSON defaultOptions { fieldLabelModifier = drop 1 }

$(makeFieldsNoPrefix ''Environment)

selectEnvironments :: Connection -> IO [Environment]
selectEnvironments connection = do
  pgEnvironmentsWithKeyValue :: [PGEnvironmentWithKeyValue] <- query connection selectEnvironmentQueryWithKeyValues (Only 1 :: Only Int)
  pgEnvironmentsWithoutKeyValues :: [PGEnvironmentWithoutKeyValue] <- query connection selectEnvironmentQueryWithoutKeyValues (Only 1 :: Only Int)

  let
    environmentsWithKeyValues =
      elems $ convertPgEnvironmentsToHashMap pgEnvironmentsWithKeyValue
    environmentsWithoutKeyValues =
      map convertPGEnviromentWithoutKeyValuesToEnvironment pgEnvironmentsWithoutKeyValues
    in
    return $ environmentsWithKeyValues ++ environmentsWithoutKeyValues
  where
    convertPgEnvironmentsToHashMap :: [PGEnvironmentWithKeyValue] -> HashMap Int Environment
    convertPgEnvironmentsToHashMap pgEnvironments =
      foldl' (\acc pgEnv -> insertWith mergeValue (pgEnv ^. environmentId) (convertPGEnviromentToEnvironment pgEnv) acc) HashMap.empty pgEnvironments

    convertPGEnviromentToEnvironment :: PGEnvironmentWithKeyValue -> Environment
    convertPGEnviromentToEnvironment pgEnv =
      let
        keyValue :: KeyValue
        keyValue =
          KeyValue { _id = pgEnv ^. keyValueId
                   , _key = pgEnv ^. key
                   , _value = pgEnv ^. value
                   }
      in
        Environment { _id = pgEnv ^. environmentId
                    , _name = pgEnv ^. environmentName
                    , _keyValues = [ keyValue ]
                    }

    convertPGEnviromentWithoutKeyValuesToEnvironment :: PGEnvironmentWithoutKeyValue -> Environment
    convertPGEnviromentWithoutKeyValuesToEnvironment pgEnv =
        Environment { _id = pgEnv ^. environmentId
                    , _name = pgEnv ^. environmentName
                    , _keyValues = []
                    }

    mergeValue :: Environment -> Environment -> Environment
    mergeValue oldEnv newEnv =
      oldEnv & keyValues %~ (++) (newEnv ^. keyValues)

    selectEnvironmentQueryWithKeyValues =
      [sql|
          SELECT
            environment.id as environment_id,
            environment.name as environment_name,
            key_value.id as key_value_id,
            key,
            value
          FROM key_value
          JOIN environment ON (key_value.environment_id = environment.id)
          JOIN account_environment ON (account_environment.environment_id = environment.id)
          WHERE account_id = ?;
          |]

    selectEnvironmentQueryWithoutKeyValues =
      [sql|
          SELECT
            environment.id as environment_id,
            environment.name as environment_name
          FROM environment
          LEFT JOIN key_value ON (key_value.environment_id = environment.id)
          JOIN account_environment ON (account_environment.environment_id = environment.id)
          WHERE key_value.environment_id IS NULL
          AND account_id = ?;
          |]

getEnvironmentsHandler
  :: ( MonadReader Config m
     , MonadIO m
     , MonadError ServerError m
     )
  => CookieSession
  -> m [Environment]
getEnvironmentsHandler _ = do
  connection <- getDBConnection
  liftIO $ selectEnvironments connection


-- * create environment


newtype NewEnvironment
  = NewEnvironment { _name :: String
                   } deriving (Eq, Show, Generic)

instance FromJSON NewEnvironment where
  parseJSON = genericParseJSON defaultOptions { fieldLabelModifier = drop 1 }

$(makeFieldsNoPrefix ''NewEnvironment)

insertEnvironment :: NewEnvironment -> Connection -> IO Int
insertEnvironment NewEnvironment { _name } connection = do
  [Only id] <- query connection insertEnvironmentQuery (Only _name)
  return id
  where
    insertEnvironmentQuery =
      [sql|
          INSERT INTO environment (
            name
          )
          VALUES (?)
          RETURNING id
          |]

bindEnvironmentToAccount :: Int -> Int -> Connection -> IO ()
bindEnvironmentToAccount accountId environmentId connection = do
  _ <- execute connection bindEnvironmentToAccountQuery (accountId, environmentId)
  return ()
  where
    bindEnvironmentToAccountQuery =
      [sql|
          INSERT INTO account_environment (
            account_id,
            environment_id
          ) values (
            ?,
            ?
          );
          |]

createEnvironmentHandler
  :: ( MonadReader Config m
     , MonadIO m
     , MonadError ServerError m
     )
  => CookieSession
  -> NewEnvironment
  -> m Int
createEnvironmentHandler _ newEnvironment = do
  connection <- getDBConnection
  environmentId <- liftIO $ insertEnvironment newEnvironment connection
  liftIO $ bindEnvironmentToAccount 1 environmentId connection >> return environmentId

-- * update environment


newtype UpdateEnvironment
  = UpdateEnvironment { _name :: String }
  deriving (Eq, Show, Generic)

$(makeFieldsNoPrefix ''UpdateEnvironment)

instance FromJSON UpdateEnvironment where
  parseJSON = genericParseJSON defaultOptions { fieldLabelModifier = drop 1 }

updateEnvironmentHandler
  :: ( MonadReader Config m
     , MonadIO m
     , MonadError ServerError m
     )
  => CookieSession
  -> Int
  -> UpdateEnvironment
  -> m ()
updateEnvironmentHandler _ environmentId updateEnvironment = do
  connection <- getDBConnection
  liftIO $ updateEnvironmentDB environmentId updateEnvironment connection

updateEnvironmentDB :: Int -> UpdateEnvironment -> Connection -> IO ()
updateEnvironmentDB environmentId UpdateEnvironment { _name } connection = do
  _ <- execute connection updateEnvironmentQuery (_name, environmentId)
  return ()
  where
    updateEnvironmentQuery =
      [sql|
          UPDATE environment
          SET name = ?
          WHERE id = ?
          |]


-- * delete environment


deleteEnvironmentHandler
  :: ( MonadReader Config m
     , MonadIO m
     , MonadError ServerError m
     )
  => CookieSession
  -> Int
  -> m ()
deleteEnvironmentHandler _ environmentId = do
  connection <- getDBConnection
  liftIO $ deleteEnvironmentDB environmentId connection

deleteEnvironmentDB :: Int -> Connection -> IO ()
deleteEnvironmentDB environmentId connection = do
  _ <- execute connection deleteEnvironmentQuery $ Only environmentId
  return ()
  where
    deleteEnvironmentQuery =
      [sql|
          DELETE FROM environment
          WHERE id = ?
          |]


-- * delete key value


deleteKeyValueHandler
  :: ( MonadReader Config m
     , MonadIO m
     , MonadError ServerError m
     )
  => CookieSession
  -> Int
  -> Int
  -> m ()
deleteKeyValueHandler _ environmentId keyValueId = do
  connection <- getDBConnection
  environments <- liftIO $ selectEnvironments connection
  let
    mKeyValue = do
      environment <- find (\environment -> environment ^. id == environmentId) environments
      find (\keyValue -> keyValue ^. id == keyValueId) $ environment ^. keyValues
  case mKeyValue of
    Just keyValue ->
      liftIO $ deleteKeyValueDB (keyValue ^. id) connection
    Nothing -> throwError err404

deleteKeyValueDB :: Int -> Connection -> IO ()
deleteKeyValueDB keyValueId connection = do
  _ <- execute connection deleteKeyValueQuery $ Only keyValueId
  return ()
  where
    deleteKeyValueQuery =
      [sql|
          DELETE FROM key_value
          WHERE id = ?
          |]


-- * upsert key values


-- ** model


data NewKeyValue
  = NewKeyValue { _newKeyValueKey   :: String
                , _newKeyValueValue :: String
                }
  deriving (Eq, Show, Generic)

instance FromJSON NewKeyValue where
  parseJSON = genericParseJSON defaultOptions { fieldLabelModifier = drop 1 }

$(makeFieldsNoPrefix ''NewKeyValue)


-- ** handler


deleteKeyValuesDB :: Int -> Connection -> IO ()
deleteKeyValuesDB environmentId connection = do
  _ <- execute connection deleteKeyValuesQuery (Only environmentId)
  return ()
  where
    deleteKeyValuesQuery =
      [sql|
          DELETE FROM key_value
          WHERE environment_id = ?
          |]

insertManyKeyValuesDB :: Int -> NewKeyValue -> Connection -> IO KeyValue
insertManyKeyValuesDB environmentId NewKeyValue { _newKeyValueKey, _newKeyValueValue } connection = do
  [keyValue] <- query connection insertKeyValueQuery (environmentId, _newKeyValueKey, _newKeyValueValue)
  return keyValue
  where
    insertKeyValueQuery =
      [sql|
          INSERT INTO key_value (environment_id, key, value)
          VALUES (?, ?, ?)
          RETURNING id, key, value
          |]


updateKeyValuesHandler
  :: ( MonadReader Config m
     , MonadIO m
     , MonadError ServerError m
     )
  => CookieSession
  -> Int
  -> [NewKeyValue]
  -> m [KeyValue]
updateKeyValuesHandler _ environmentId newKeyValues = do
  connection <- getDBConnection
  environments <- liftIO $ selectEnvironments connection
  let
    environment = find (\env -> env ^. id == environmentId) environments
  case environment of
    Just _ -> do
      liftIO $ deleteKeyValuesDB environmentId connection
      liftIO $ mapM (flip (insertManyKeyValuesDB environmentId) connection) newKeyValues
    Nothing ->
      throwError err404