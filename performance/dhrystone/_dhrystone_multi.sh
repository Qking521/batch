while true
do
 /data/dhrystone.elf < /data/input.txt >> /data/dhrystone_results_$1.txt
 #grep 'Dhrystones per.*$' /data/dhrystone_results_$1.txt 
done