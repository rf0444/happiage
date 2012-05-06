module Handler.Register where

import Import
import qualified Data.Text as T

--参加登録ページ
getRegisterR :: Handler RepHtml
getRegisterR = do
  maid <- maybeAuthId
  muid <- maybeUserId maid
  case maid of
    Nothing -> --not logged in
      defaultLayout [whamlet|<h2>参加登録をするためには、ログインをしてください|]
    Just authId -> 
      case muid of 
        Just _ -> 
          defaultLayout [whamlet|<h2>参加登録はすでに完了しています。<br>
            <a href=@{MessageR}>新郎新婦へのメッセージを投稿しますか？</a><br>
            <a href=@{RegupdateR}>または、参加登録を変更しますか？</a>|]
        Nothing -> do --not registered 
          ((_, widget), enctype) <- runFormPost registerForm
          defaultLayout $ do
            h2id <- lift newIdent
            let title = T.pack "参加登録"
            $(widgetFile "entry")

postRegisterR :: Handler RepHtml
postRegisterR = do
  ((res, widget), enctype) <- runFormPost registerForm
  mUserRegisterInfo <- case res of
    FormSuccess userRegisterInfo -> return $ Just userRegisterInfo
    _ -> return Nothing
  maid <- maybeAuthId
  --ログイン時、postデータがあった場合に、書き込み
  case (mUserRegisterInfo, maid) of
    (Just userRegisterInfo, Just authid) ->
      runDB $ do --TODO:runDBのエラーチェック
        _ <- insert $ User {
          userAuthid = authid, 
          userName = urName userRegisterInfo, 
          userKananame = urKananame userRegisterInfo, 
          userZipcode = urZipcode userRegisterInfo,
          userAddress = urAddress userRegisterInfo,
          userSex = urSex userRegisterInfo, 
          userAttend = urAttend userRegisterInfo, 
          userInvitedby = Nothing, 
          userDeleted = False
        }
        return ()
    _ -> return ()
  defaultLayout $ case (mUserRegisterInfo, maid) of
    (Just _, Just _) -> do
      [whamlet|<h2>参加登録が完了しました！|]
    _ -> do
      h2id <- lift newIdent
      let title = T.pack "参加登録"
      $(widgetFile "entry")

--参加登録更新ページ
getRegupdateR :: Handler RepHtml
getRegupdateR = do 
  maid <- maybeAuthId
  muid <- maybeUserId maid
  case maid of
    Nothing -> --not logged in
      defaultLayout [whamlet|<h2>参加登録情報の変更には、ログインをしてください|]
    Just authId -> 
      case muid of 
        Nothing -> do --not registered 
          ((_, widget), enctype) <- runFormPost registerForm
          defaultLayout $ do
            h2id <- lift newIdent
            let title = T.pack "参加登録"
            $(widgetFile "entry")
        Just userId -> do
          user <- runDB $ get404 userId
          ((_, widget), enctype) <- runFormPost (updateForm $ Just user)
          defaultLayout $ do
            h2id <- lift newIdent
            let title = T.pack "参加登録情報更新"
            $(widgetFile "entry")

--参加登録更新ページ
postRegupdateR :: Handler RepHtml
postRegupdateR = do
  ((res, widget), enctype) <- runFormPost $ updateForm Nothing
  mUserUpdateInfo <- case res of
    FormSuccess userUpdateInfo -> return $ Just userUpdateInfo
    _ -> return Nothing
  maid <- maybeAuthId
  muid <- maybeUserId maid
  --ログイン時、postデータがあった場合->ユーザ登録
  case (mUserUpdateInfo, maid, muid) of
    (Just userUpdateInfo, Just authid, Just uid) ->
      runDB $ do --TODO:runDBのエラーチェック
        orig <- get404 uid
        replace uid User {
          userAuthid = authid, 
          userName = urName userUpdateInfo,
          userKananame = urKananame userUpdateInfo,
          userZipcode = urZipcode userUpdateInfo,
          userAddress = urAddress userUpdateInfo,
          userSex = urSex userUpdateInfo, 
          userAttend = urAttend userUpdateInfo, 
          userInvitedby = Nothing, 
          userDeleted = False
        }
        return ()
    _ -> return ()
  defaultLayout $ case (mUserUpdateInfo, maid) of
    (Just _, Just _) -> do
      [whamlet|<h2>参加登録情報を変更しました！|]
    _ -> do
      h2id <- lift newIdent
      let title = T.pack "参加登録"
      $(widgetFile "entry")

--フォームの選択要素
genderFieldList :: [(Text, Sex)]
genderFieldList = (zip (map T.pack ["男性","女性"]) [Male, Female])

attendFieldList :: [(Text, Attend)]
attendFieldList = (zip (map T.pack ["保留","欠席","出席"]) [Suspense, Absent, Present])

--参加登録用フォーム
registerForm :: Html -> MForm Happiage Happiage (FormResult UserRegisterInfo, Widget)
registerForm = renderDivs $ 
  UserRegisterInfo
    <$> areq textField "名前" Nothing
    <*> areq textField "名前かな" Nothing
    <*> areq textField "郵便番号" Nothing
    <*> areq textField "住所" Nothing
    <*> areq (selectFieldList genderFieldList) "性別" Nothing
    <*> areq (selectFieldList attendFieldList) "ご出席" Nothing

data UserRegisterInfo = UserRegisterInfo
      { urName :: Text
      , urKananame :: Text
      , urZipcode :: Text
      , urAddress :: Text
      , urSex :: Sex
      , urAttend :: Attend
      }
    deriving Show

--参加登録更新用フォーム（一部項目のみ変更可能）
updateForm :: Maybe User -> Html -> MForm Happiage Happiage (FormResult UserRegisterInfo, Widget )
updateForm muser = renderDivs $ 
  UserRegisterInfo
    <$> areq textField "名前" (fmap userName muser)
    <*> areq textField "名前かな" (fmap userKananame muser)
    <*> areq textField "郵便番号" (fmap userZipcode muser)
    <*> areq textField "住所" (fmap userAddress muser)
    <*> areq (selectFieldList genderFieldList) "性別" (fmap userSex muser)
    <*> areq (selectFieldList attendFieldList) "ご出席" (fmap userAttend muser)
