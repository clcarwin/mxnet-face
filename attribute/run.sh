#!/usr/bin/env sh 

# here do not use the the aligned celeba, because we do not know how they align, we need better konw all things in our algorithm
raw_data_path=/home/work/data/Face/CelebA/Img/img_celeba
crop_data_path=/home/work/data/Face/CelebA/Img/img_celeba_cropped
num_process=22
landmarks=innerEyesAndBottomLip
face_size=144
ts=0.1
# this is the empirical ratio to pad the face rect
pad='0.25 0.25 0.25 0.25'
crop_done=.done_crop
# for generate .lst
list_name=${crop_data_path}/celeba
partition_file=/home/work/data/Face/CelebA/Eval/list_eval_partition.txt
anno_file=/home/work/data/Face/CelebA/Anno/list_attr_celeba.txt
# for im2rec
im2rec_path=/home/work/wuwei/project/dmlc/mxnet/bin/im2rec
rec_name=celeba

# step1: crop the face iamge
[ -e $crop_data_path ] || mkdir -p $crop_data_path
if ! [ -e $crop_done ];then
   for N in $(seq $num_process);do
	  echo "the sub-process is : $N"	
	  python ../util/align_face.py $raw_data_path --only-crop align $landmarks $crop_data_path --pad $pad --ts $ts &
   done
   wait
   echo 'using dlib for crop face is done'
   for N in $(seq $num_process);do
	  python ../util/align_face.py $raw_data_path --opencv-det --only-crop align $landmarks $crop_data_path --pad $pad --ts $ts &
   done
   wait
   echo 'using opencv for crop face is done'
   touch $crop_done 
else
   echo "$crop_done has already exist."
fi
wait
echo "Align face image done"

# step2: generate .lst for im2rec, together with cacling the src distribution
cmd=../util/gen_celeba_lst4im2rec.py
if ! [ -e src_dict.txt ];then
   ls $crop_data_path/img_celeba > ${list_name}.lst
   python -u $cmd --root $crop_data_path --src-list ${list_name}.lst --partition $partition_file --anno $anno_file --shuffle
else
   echo ".lst file for training already exist."
fi
echo "generated .lst file done" 

# step3: use img2rec to generate .rec file for training
if ! [ -e ${rec_name}_train.rec ]; then
	$im2rec_path ${list_name}_train.lst $crop_data_path/img_celeba/ ${rec_name}_train.rec resize=160 label_width=40 color=0 encoding='.png' &
	$im2rec_path ${list_name}_val.lst $crop_data_path/img_celeba/ ${rec_name}_val.rec resize=160 label_width=40 color=0 encoding='.png' &
else
	echo "$rec_name already exist."	
fi
wait
echo "generate .rec done"

# step4: trainig the model for face attribute prediction 
#python -u lightened_moon.py 
#python -u lightened_moon.py --gpus 0
#python -u lightened_moon.py --gpus 4,5,6,7
python -u lightened_moon.py --gpus 2,3,4,5,6,7
#python -u lightened_moon.py --gpus 2,3,4,5,6,7 --retrain
echo "trining done!"
