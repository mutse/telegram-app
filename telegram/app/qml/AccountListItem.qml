import QtQuick 2.4
import QtMultimedia 5.0
import Ubuntu.Components 1.3
import Ubuntu.Components.ListItems 1.3 as ListItem

import AsemanTools 1.0
import TelegramQML 1.0

// Cutegram: AccountFrame.qml

Item {
    id: account_list_item

    property ProfilesModelItem accountItem
    property AccountPage dialogsPage
    property int notifyTimeOut: 3000
    property bool isActive: true // TODO alias to main view activeFocus

    property alias telegramObject: telegram
    property alias unreadCount: telegram.unreadCount

    signal activeRequest()
    signal addParticipantRequest()

    onIsActiveChanged: {
        telegram.online = isActive;
    }

    function show() {
        console.log("calling show");
        pageStack.primaryPageSource = dialogs_page_component;
    }

    function setPrimaryPage() {
        // Set primary page in AccountListItem with synchronous mode of APL
        pageStack.primaryPage = introPage;
    }

    QtObject {
        id: privates
    }

    Connections {
        target: mainView
        onPushRegister: {
            if (Cutegram.pushNumber == telegram.phoneNumber) {
                telegram.accountRegisterDevice(token, version);
            }
        }
        onPushUnregister: {
            if (Cutegram.pushNumber == telegram.phoneNumber) {
               telegram.accountUnregisterDevice(token);
           }
        }
    }

    Telegram {
        id: telegram

        property bool logoutRequest: false

        defaultHostAddress: Cutegram.defaultHostAddress
        defaultHostDcId: Cutegram.defaultHostDcId
        defaultHostPort: Cutegram.defaultHostPort
        appId: Cutegram.appId
        appHash: Cutegram.appHash
        downloadPath: "/home/phablet/.cache/com.ubuntu.telegram"
        tempPath: "/home/phablet/.cache/com.ubuntu.telegram"
        configPath: AsemanApp.homePath
        publicKeyFile: AsemanApp.appPath + "/tg-server.pub"
        phoneNumber: accountItem.number
        autoCleanUpMessages: true
        autoAcceptEncrypted: true

        onErrorSignal: {
            if (errorText === "SESSION_REVOKED") {
                telegram.logoutRequest = true;
                telegram.authLogout();
            } else if (errorText === "AUTH_KEY_UNREGISTERED") {
                telegram.logoutRequest = true;
                telegram.authLogout();
            }

            mainView.error(id, errorCode, errorText)
        }
        onErrorChanged: {
            console.log("auth error: " + error)
        }
        onAuthNeededChanged: {
            console.log("authNeeded " + authNeeded)
        }
        onAuthPhoneCheckedChanged: {
            console.log("authPhoneChecked " + authPhoneChecked)
        }
        onAuthCallRequested: {
            console.log("authCallRequested")
        }
        onAuthCodeRequested: {
            console.log("authCodeRequested");
            account_list_item.setPrimaryPage();
            pageStack.addPageToCurrentColumn(pageStack.primaryPage, account_code_page_component, {
                    "phoneRegistered": telegram.authPhoneRegistered,
                    "timeOut": sendCallTimeout
                });
        }
        onAuthLoggedInChanged: {
            readyForPush = authLoggedIn; // required for PushClient

            if (authLoggedIn) {
                console.log("authLoggedIn true");
                account_list_item.show();

                if (Cutegram.pushNumber == "") {
                    Cutegram.pushNumber = phoneNumber;
                }

                if (Cutegram.pushNumber == phoneNumber) {
                    if (!push_client_loader.active) {
                        push_client_loader.active = true;
                    } else if (push_client_loader.status === Loader.Ready) {
                        pushClient.registerForPush();
                    }
                }
            } else {
                console.log("authLoggedIn false");
                if (logoutRequest) {
                    Cutegram.logout(phoneNumber);
                }
            }
        }
        onAccountDeviceRegistered: {
        }
        onAccountDeviceUnregistered: {
            if (logoutRequest) {
                Cutegram.pushNumber = "";
            }
            Cutegram.pushNotifications = false;
        }
        onMessagesSent: outgoingMessagesMetric.increment(count)
        onMessagesReceived: incomingMessagesMetric.increment(count)

        onConnectedChanged: {
            if (connected && authLoggedIn) {
                telegram.updatesGetState();
            }
        }
    }

    Component {
        id: account_code_page_component

        AuthCodePage {
            id: auth_code_page
            objectName: "auth_code_page"

    //        property bool authNeeded: (telegram.authNeeded
    //                || telegram.authSignInError.length != 0
    //                || telegram.authSignUpError.length != 0)
    //                        && telegram.authPhoneChecked

            onSignInRequest: telegram.authSignIn(code)
            onSignUpRequest: telegram.authSignUp(code, fname, lname)
            onCodeRequest: telegram.authSendCode()
            onCallRequest: telegram.authSendCall()

            Connections {
                target: telegramObject
                onAuthSignInErrorChanged: auth_code_page.error(telegramObject.authSignInError)
                onAuthCallRequested: auth_code_page.allowCall = false
            }
        }
    }

    AccountLoading {
        anchors.fill: parent
        z: 10
        active: (!telegram.authLoggedIn && telegram.authNeeded) || !telegram.authPhoneChecked
    }

    Component {
        id: dialogs_page_component

        AccountPage {
            id: dialogs_page
            telegramObject: telegram
            profileCount: profiles.count
        }
    }
    
    IntroPage {
        id: introPage
    }
}
