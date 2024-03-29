#!/usr/bin/env bash
# Barthelemy Caron, Clinical BioInformatics Lab, IMAGINE
# Modified by Fabio Zanarello, Sanger Institute, 2019

inF=$1
outF=$2
PCtab=$3
PCth=$4

file_name=${inF:0:(${#inF}-4)}

#Fabio Zanarello, Sanger Institute, 2019
#START_my_chages################################################################
# default value for PCHIC is 5

if [ -z $PCth ];then
  PCth=5
fi
#END_my_chages##################################################################

path_to_annovar='annovar'
path_to_cadd='NCBoost_features'


# sorting data for tabix
echo $'\nsorting data\n'
sort -k1,1 -k2,2n $inF -o $inF



# 1- ANNOVAR gene-based annotation
echo $'\nLaunching ANNOVAR\n'
anno_out=$file_name
perl $path_to_annovar/annotate_variation.pl -out $anno_out -build hg19 -splicing_threshold 10 $inF $path_to_annovar/humandb/



# 2- clean ANNOVAR output file, add gene-based features, one-hot encoding of the regions (~200 var/sec)
echo $'\n\nCleanning ANNOVAR annotations, adding gene-based and context-awareness features\n'
python3.6.1 NCBoost_scripts/clean_annovar_PCIHC.py $anno_out.variant_function $anno_out.invalid_input $anno_out.cleaned_variant_function  $PCth $PCtab $anno_out.PC_res


# 3- extract features from CADD (~9 var/sec)
echo $'\n\nAdding CADD features\n'
python3.6.1 NCBoost_scripts/get_cadd_features.py $anno_out.cleaned_variant_function $anno_out'_cadd.tsv' $path_to_cadd



# 4- extract 1000 Genome Project features (~220 var/sec)
echo $'\n\nAdding 1000 Genome Project positive selection scores\n'
python3.6.1 NCBoost_scripts/get_1000GP_possel_scores.py $anno_out'_cadd.tsv' $anno_out'_cadd_1000GP.tsv'



# 5- extract 1000 Genome Project positive selection scores (~200 var/sec)
echo $'\n\nAdding 1000 Genome Project mean heterozygosity and DAF\n'
python3.6.1 NCBoost_scripts/get_1000GP_daf_het.py $anno_out'_cadd_1000GP.tsv' $anno_out'_cadd_1000GP_full.tsv'



# 6- extract GnomAD features (~6 var/sec)
echo $'\n\nAdding GnomAD MAFs\n'
python3.6.1 NCBoost_scripts/get_GnomAD_MAFs.py $anno_out'_cadd_1000GP_full.tsv' $anno_out'_cadd_1000GP_gnomad.tsv'



# 7- extract CDTS score (~270 var/sec)
echo $'\n\nAdding CDTS score\n'
python3.6.1 NCBoost_scripts/get_CDTS.py $anno_out'_cadd_1000GP_gnomad.tsv' $anno_out'_complete.tsv'

#START_my_chages################################################################

# 8- Scoring with NCBoost (~60 var/sec)
echo $'\n\nRunning NCBoost\n'
n_rows_in_file=($(wc -l $anno_out'_complete.tsv'))
n_columns_in_file=($(head -1 $anno_out'_complete.tsv' | sed 's/[^\t]//g' | wc -c))
/software/R-3.4.2/bin/Rscript NCBoost_scripts/NCBoost_score.R $anno_out'_complete.tsv' $file_name.temp_res $n_rows_in_file $n_columns_in_file


echo $'\n\nAdding PC stat\n'
python3.6.1 NCBoost_scripts/add_PC_stat.py --NC_res $file_name.temp_res --PC_stat $anno_out.PC_res --NC_update $outF


#END_my_chages##################################################################


echo $'\n\n cleaning\n'

rm $anno_out'_cadd.tsv'
rm $anno_out'_cadd_1000GP.tsv'
rm $anno_out'_cadd_1000GP_full.tsv'
rm $anno_out'_cadd_1000GP_gnomad.tsv'
rm $anno_out'_complete.tsv'
rm $anno_out'.variant_function'
rm $anno_out'.cleaned_variant_function'
rm $anno_out'.exonic_variant_function'
rm $anno_out'.invalid_input'
rm $anno_out'.log'

#START_my_chages################################################################


rm $anno_out'.PC_res'
rm $file_name'.temp_res'

#END_my_chages################################################################
