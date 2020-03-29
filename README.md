# San Andreas RadioEx
Copyright © Thiekus (Faris Khowarizmi) 2014 - 2020
Free and Open Source under MPL 2.0
Project repository at https://github.com/thiekus/sa-radioex

San Andreas RadioEx is asi script that allow you to replace current radio stations.
It's like San Andreas Own Radio Station by HackMan128, but with lot improvements:
* It's asi script! Just run gta-sa.exe and it will run.
* No need to replace any GTA files! It has own stream file emulation.
* It have cool loading sound when stream buffer on progress
* It have custom notification sound when cannot open stream (English and Indonesian).
* Resolves most anticipated bug in SAORS like missing sound.
* You can replace the radio name without replacing on *.gxt file (altrough have some limitations).
* Not only MP3 radio streams, RadioEx also support MP4 and Opus.
* Free and open source under LGPL 2.1 (coded in Delphi).

How to Install?

I recomended to use Slinet's ASI Loader (It's performs better):
http://www.gtagarage.com/mods/show.php?id=21709

Then, place RadioEx.asi, RadioEx.ini and some bass library support on GTA SA directory. Edit RadioEx.ini with your mind! For list of Radio Streaming URL, just Google it :)

(IMPORTANT! You must set EnableBassInit to 0 if you have CLEO installed or asi that use bass.dll dependency) And, if you indonesian, leave NoticeLang to ID, otherwise must EN.
(To hear "Cannot open radio baby!", instead "Tidak bisa membuka radio, gan!")

Play and feel the difference!

Changelogs:

### V 1.1.0.253 (23 August 2014)
````
+ Faster radio change.
+ Adverts stream are emulated.
````

### V 1.0.2.244 (21 August 2014)
````
* Fix string memory buffer leaks and c call function fault. This will resolve problem when creating thread but insufficient memory.
* Some minor changes on initialization stage.
* Change from WinAPI CreateThread to BeginThread.
````

### V 1.0.1.234
````
* Initial release
````

Known issues and limitations:
* It only support GTA SA version 1.0
* It's have RadioNamePatch feature, sometimes like just not work (will back to original, but instantly patched) because I not patch all possible text loader for technical reasons.
* Only internet radio streaming player ability, your music files will play soon... :)

## License

San Andreas RadioEx is licensed under Mozilla Public License (MPL) 2.0.
