#!/bin/bash
#-------------------------------------------------------------------------------------------------------------#
#       Script Information                                                       											#
#-------------------------------------------------------------------------------------------------------------#
#Script Name:   Disk_usage_OnPrem.sh                                                                              				#
#Description:   	This script gives the the status of usage of disks by ASM/LVM it create files #
#           			  UsedDisks_<hostname>.txt and UnUsedDisks_<hostname>.txt			#
# Usage: Copy the contents of the script and run the same									#
# Assumption: Script needs to be run where multipathing is used i.e. OnPrem Servers		#
#-------------------------------------------------------------------------------------------------------------#
#                         										                                                                             	#
#                                                                                                             										#
#-------------------------------------------------------------------------------------------------------------#
#                                               Version Log                                                  								 #
#-------------------------------------------------------------------------------------------------------------#
# 2025-Jan-14 - Sampath Kumar Bodiga  - initial version                                                      			 #
#-------------------------------------------------------------------------------------------------------------#

ls /dev/mapper |grep mpath>ocr_disk_list
OCR_DISK_LIST_PATH=ocr_disk_list
>UsedDisks_`hostname`.txt
>UnUsedDisks_`hostname`.txt
echo "DeviceName|Size|Measurement|Status" >UsedDisks_`hostname`.txt
echo "DeviceName|Size|Measurement|Status" >UnUsedDisks_`hostname`.txt

for disk in `cat $OCR_DISK_LIST_PATH`;
do
DName="/dev/mapper/"
DName+=${disk}
if [ ${DName: -1} != 1 ]
then
if [[ `cat /dev/oracleafd/disks/* | grep ${DName}1` == ''  ]]
then
if [ `blkid | grep ${DName}1 | wc -l`  == 1 ]
then
fdisk -l ${DName} | head -1 | awk '{print substr($2, 1, length($2)-1)"|" $3 "|" substr($4, 1, length($4)-1) "|PartitionedNotUsedByASM"}' >>UnUsedDisks_`hostname`.txt
elif [ `blkid | grep ${DName} | grep LVM | wc -l`  == 1 ]
then
fdisk -l ${DName} | head -1 | awk '{print substr($2, 1, length($2)-1)"|" $3 "|" substr($4, 1, length($4)-1) "|NotPartitionedUsedByLVM"}' >>UnUsedDisks_`hostname`.txt
else
fdisk -l ${DName} | head -1 | awk '{print substr($2, 1, length($2)-1)"|" $3 "|" substr($4, 1, length($4)-1) "|NotPartitionedUsedByLVM"}' >>UnUsedDisks_`hostname`.txt
fi
fi
else
fdisk -l ${DName} | head -1 | awk '{print substr($2, 1, length($2)-1)"|" $3 "|" substr($4, 1, length($4)-1) "|UsedByASM"}' >>UsedDisks_`hostname`.txt
fi
done;