add-vpnconnection `
-name "Ahima RRAS" `
-ServerAddress "rras.ahima.org" `
-AllUserConnection `
-TunnelType "sstp" `
-AuthenticationMethod "MSChapv2" `
-EncryptionLevel "Optional" `
-UseWinlogonCredential `
-SplitTunneling `
-DnsSuffix "ahima.local" 
