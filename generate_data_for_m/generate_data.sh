#!/bin/bash

rm tmp.txt

# SERIAL
for ((i=0; i<647; ++i))
do  
    cat End_of_Frame_1PP.txt >> tmp.txt
done


# SYNC
for ((i=0; i<657; ++i))
do  
    cat Training_pattern_1PP.txt >> tmp.txt
done

# DELAY

for ((i=0; i<656; ++i))
do  
    cat Training_pattern_1PP.txt >> tmp.txt
done

# READOUT
for ((i=0; i<320; ++i))
do
    for ((j=0; j<8; ++j))
    do
        cat Training_pattern_1PP.txt >> tmp.txt
    done

    for ((j=0; j<320; ++j))
    do
        cat Data_word_1PP.txt >> tmp.txt
    done
done

for ((i=0; i<8; ++i))
do  
    cat End_of_Frame_1PP.txt >> tmp.txt
done

# FRAMES
for ((i=0; i<10; ++i))
do  
    echo "frame "$i
    cat tmp.txt >> frames.txt
done

mv frames.txt data.dat
rm tmp.txt


