[x] Handle chat with non-friends: Accessible via "Send Message" button on User Profile Dialog (`UserProfileDialog`), launching 1-on-1 direct messaging (`DmChatScreen`) with any user.
[x] Chat messages routed exclusively to notification panel (persisted, single notification per sender, unread badge on dashboard, clicking notification navigates to chat).
[x] When a chat with unread messages are opened, delete their notification.
[x] We should be able to send challenge invitation to multiple people (we are preventing this right now). If one of them accepts, the other invites should cancel. Also when close and reopen the app, sent challenges are gone. And remove friendOfflineInviteNote.
[x] If an invitation, or open room etc. has an expiration time (like a sent challenge invitation or an invitation you get expires in x mins, idk how it works), put a timer on the card.
[x] We should seperate active online match and active offline match. Currently player can only be on one match (offline or online). Player should be able to be one offline match AND one online match. So being in an offline match shouldn't affect joining an online match or vice versa. Remove the code parts where offline and online matches prevent each other.
[x] Online matches doesn't show up on chat immediately. When I close the app and reopen the match shows up on chat.
[x] Order friends depending on last interaction (match/chat).
[x] When you leave the app on mobile (not closing it, changing the tab) and come back after a few minutes, it shows the offline main menu first and then change to online.
[x] If the internet is bad, there is an "checking connection" loading screen. Put "continue offline" button there, so we don't have to wait until we get an answer from api.
[x] If you are offline and not logged in, you are automatically logged in as guest instead of showing the login screen. We should instead show the login screen.
[x] There is a gap between "offline active match" and "online active match" cards on the main menu. Also swap the colors of offline and online active matches. (Online -> Mint (accent), Offline -> Purplish red (main color). This is the exact opposite right now.)