i=0
interations=$1
while [ $i -lt $interations ]
do
 echo "Executing Dhrystone "
 /data/_dhrystone_multi.sh $i &
 i=`expr $i + 1`
done
