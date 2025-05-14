#!/bin/bash

# Clean previous outputs


# First split: first 15 lines, into 3 files of 5 lines each
split -l 5 -d -a 1 <(head -n 15 list.txt) file
mv file0 file1.txt
mv file1 file2.txt
mv file2 file3.txt

# Second split: remaining 93 lines, into chunks of 10
tail -n +16 list.txt | split -l 10 -d -a 1 - file

# Rename resulting files to file4.txt up to file10.txt
n=4
for f in file?; do
  mv "$f" "file${n}.txt"
  ((n++))
done

echo "✅ Done: 10 files created"

