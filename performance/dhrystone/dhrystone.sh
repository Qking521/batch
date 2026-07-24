while true
do
 /data/dhrystone.elf < /data/input.txt >> /data/dhrystone_results.txt
 grep 'Dhrystones per.*$' /data/dhrystone_results.txt
done