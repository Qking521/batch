Dhrystone Procedure

About Dhrystone:

Dhrystone is a binary which can help in loading cpu cores to measure power for a particular core/cluster at differnet frequencies.
Running one instance of dhrystone binary will load one core i.e. if you want to measure power of one core with 100 % load ,you need to run one instance of dhrysone.sh binary.
In same way if its 4cores you need to run 4 instances of dhryston.sh commands.


Hardware devices & Reworks:

1.Power Rework your device(QRD/Mobile Handset) to measure Battery power.
2.We are using Monsoon power monitors to measure battery power of our reference devices.


Steps to install Dhrystone :

1. Disable location services,NFC & keep device in APM(Air plane mode).Make sure your device is going to sleep.
2. Make sure your battery percentage is constant at a particular level.If its showing low percentage try to adjust it above 65% by giving 4.2V as voltage source or fakebattery command.
     adb shell setprop persist.bms.fake_batt_capacity 75 (This command may change target to target)

3. Connect USB and Install Dhrystone binary to data directory by running install_dhrystone_64.bat file which is avilable in the folder.


4. Run the batch file > install_dhrystone/install_dhrystone_64.bat (64 bit) or 
                        install_dhrystone/install_dhrystone.bat (32 bit)

   This batch files does the following 

   1) Pushing the .elf and .sh  files to /data/
   2) Giving  execution permission to the scripts 


Steps to run Dhrystone :

Measuring Gold Cluster Dhrystone power @ Max frequncy.

4. Run Gold_cluster_Fmax.bat from location HS11-PG319-12HW\Batfiles.

Understanding Commands related above batch file.

a. Wakelock command to awake device as we are keeping display off. 
b. Disabling all silver cores, as we are measuring Gold cluster dhrystone power.
c. Make sure all gold cores are enabled.
d. Set all gold core Scaling frequencies i.e Min & Max to highest frequency levels so that it will be fixed/freezed at that levels.
e. Set all gold core governors to performance mode.
f. Verify all the above settings by running cat/readings commands.
g. Measure CPU Junction temperatures and make sure they are at 25-30C.
h. Now go to adb shell --> cd data --> ./dhrystone.sh & (Give ./dhrystone.sh & ...Two instances as we have 2 gold cores over here,3cores online-->3 times Dhrystone instances ,4 cores --> 4 times dhrystone instances)
i. Remove USB and display off the screen and measure dhrystone power using power monitor tool.
j. Measure power for a required time & and save power waveform.
k. Connect USB and pull Dhrystone results to measure DMIPS using below command.

         adb pull /data/dhrystone_results.txt

Procedure to measure DMIPS=Avg of Dhrystone measured per second  from above .txt file /1757

Note : Make sure we are not seeing any thermal mitigations happening.For octacore dhrystone running at max frequency, we might see thermal rules getting triggered after 2-4 Mins.




