/*
           __
           ||              # ADVANCED LIGHT MICROSCOPY - i3S
         ====
         |  |__            Bruno S. Monteiro (brunom@i3s.up.pt)
         |  |-.\           Maria Azevedo (maria.azevedo@i3s.up.pt)
         |__|  \\          Paula Sampaio (sampaio@i3s.up.pt)
          ||   ||         
        ======__|         **************************************************
       ________||__                MULTICHANNEL BACKGROUND ANALYZER
      /____________\      **************************************************                             
                                     Last updated: 10/01/25
  
**Input**
  - Multichannel fluorescence images
 
**Output**
  -A results table (`Results_Mean.csv`) containing the mean gray values for two channels per image

**Workflow Overview**
This macro automates the analysis of multi-channel images, focusing on calculating mean gray values in a centered square selection for the 2 first channels:

  1. For each image file, the Bio-Formats plugin is used to load and process the data.
  2. A centered square ROI is defined, and the mean gray values of two selected channels are measured.
  3. Results are stored in a new table that includes the image name and mean values for both channels.

**Attribution**
 If you use this macro please in your papers and/or thesis (MSc and PhD), acknowledging the i3S Scientific Platforms involved in your work is encouraged (C.E. 17/07/2017). 
 For the acknowledgment to the ALM, please use one of the following sentences (as a reference):
 
     "The authors acknowledge the support of i3S Scientific Platform Advanced Light Microscopy, member of the national infrastructure PPBI-Portuguese Platform of BioImaging (supported by POCI-01-0145-FEDER-022122)."
     "The authors acknowledge the support of i3S Scientific Platform Advanced Light Microscopy, a site of PPBI Euro-Bioimaging Node"

 Please send us the reference of your published work involving our unit.
 
**Copyrights**
 All rights to the work developed by the ALM team are reserved. We kindly ask you not to transmit any information by any means without express permission from the author(s).

*/

close("*");
print("\\Clear")
run("Clear Results");
roiManager("reset");
setBatchMode(true);

#@ File (label = "Input directory", style = "directory") input
#@ String (label = "File suffix", value = ".nd2") suffix
#@ File (label = "Output directory", style = "directory") output

Table.create("Results_Mean");

processFolder(input);

// function to scan folders/subfolders/files to find files with correct suffix
function processFolder(input) {
	list = getFileList(input);
	list = Array.sort(list);
	for (k = 0; k < list.length; k++) {
		if(File.isDirectory(input + File.separator + list[k]))
			processFolder(input + File.separator + list[k]);
		if(endsWith(list[k], suffix))
			processFile(input, output, list[k]);
	}
}


function processFile(input, output, file) {
run("Bio-Formats Macro Extensions"); 
run("Bio-Formats", "open=" + input + File.separator + file +" color_mode=Default rois_import=[ROI manager] view=Hyperstack stack_order=XYCZT");    
    title = getTitle();
    img_name = replace(title, suffix, "");

    
    Stack.setChannel(1);
    run("Specify...", "width=512 height=512 x=256 y=256 slice=1"); // Draw center square selection
    roiManager("Add");

    // Measure mean gray values for both channels
    run("Set Measurements...", "mean redirect=None decimal=3");
    roiManager("Measure");
    Stack.setChannel(2);
    roiManager("Measure");

    // Retrieve and store measurements in new results table
    ch1_mean = Table.get("Mean", 0, "Results");
    ch2_mean = Table.get("Mean", 1, "Results");
    Table.set("Image Name", k, img_name, "Results_Mean");
    Table.set("CH1 Mean", k, ch1_mean, "Results_Mean");
    Table.set("CH2 Mean", k, ch2_mean, "Results_Mean");
    close(title);
    roiManager("reset");
    
    close("Results");    
}

selectWindow("Results_Mean");
saveAs("Measurements", output + File.separator + "Results_Mean.csv");
close("Results_Mean.csv");

