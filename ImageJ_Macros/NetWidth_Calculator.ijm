/*
           __
           ||              # ADVANCED LIGHT MICROSCOPY - i3S
         ====
         |  |__            Bruno S. Monteiro (brunom@i3s.up.pt)
         |  |-.\           Maria Azevedo (maria.azevedo@i3s.up.pt)
         |__|  \\          Paula Sampaio (sampaio@i3s.up.pt)
          ||   ||         
        ======__|         **************************************************
       ________||__                 	Net Width Calculator
      /____________\      **************************************************                             
       								Last updated: 17/03/25
       
Requirements

  - FIJI
  - Local Thickness plugin installed
  
Workflow Overview

This Fiji macro is designed to calculate the width of net-like 3D structures in single-channel fluorescenceimages

1. The 3D stack is condensed into a 2D image using a maximum intensity projection

2. The net-like structures in the 2D projection are segmented using an automatic thresholding method to isolate the relevant signal.

3. The resulting binary mask is used to produce a map of the local thickness and a skeleton of the network.

4. The product of the local thickness map and the skeleton image provides a representation of the width of the structures along their length.

5. The result is the mean width of the structures, calculated from all pixels in the final width map.
      
Attribution
 If you use this macro please in your papers and/or thesis (MSc and PhD) acknowledging the i3S Scientific Platforms involved in your work is encouraged (C.E. 17/07/2017). 
 For the acknowledgment to the ALM, please use one of the following sentences (as a reference):
 
     "The authors acknowledge the support of i3S Scientific Platform Advanced Light Microscopy, member of the national infrastructure PPBI-Portuguese Platform of BioImaging (supported by POCI-01-0145-FEDER-022122)."
     "The authors acknowledge the support of i3S Scientific Platform Advanced Light Microscopy, a site of PPBI Euro-Bioimaging Node"

 Please send us the reference of your published work involving our unit.

Copyrights
 All rights to the work developed by the ALM team are reserved. We kindly ask you not to transmit any information by any means without express permission from the author(s).

*///------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

Titles = getList("window.titles");
for (i=0; i< Titles.length; i++) // closes all open windows
	if ( Titles.length != 0) {
	selectWindow(Titles[i]);
	close(Titles[i]);
	}
//setBatchMode(true);

#@ File (label = "Input directory", style = "directory") input
#@ String (label = "File suffix", value = ".ics") suffix
#@ File (label = "Output directory", style = "directory") output
#@ String (choices = ["1", "2", "3", "4"], label = "Net Channel") net_ch
#@ Double (label="Nets Minimum Area (pxl)", value=6) net_minarea

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
    
    print("Processing " + img_name);

run("Duplicate...", "title=web duplicate channels="+net_ch+""); // duplicate original image and extract channel stack to be quantified
close(title);
run("Z Project...", "projection=[Max Intensity]"); // convert 3D stack to 2D image
close("web");

//Segmentation of nets
setOption("ScaleConversions", true);
run("8-bit");
setAutoThreshold("Triangle dark no-reset"); //choose automatic thresholding method that best suits your images
setOption("BlackBackground", true);
run("Convert to Mask");
run("Set Measurements...", "  redirect=None decimal=3");
run("Analyze Particles...", "size="+net_minarea+"-Infinity pixel circularity=0.00-0.8 show=Masks"); // filter out unwanted small roundish objects
run("Invert LUT"); //check if it is needed
close("MAX_web");

run("Duplicate...", "title=sk");

//Determine local thickness of binary mask
selectImage("Mask of MAX_web");
run("Local Thickness (masked, calibrated, silent)");
close("Mask of MAX_web");

//Skeletonize binary mask
selectImage("sk");
run("Skeletonize");
run("Divide...", "value=255");

//Calculate mean thickness 
imageCalculator("Multiply 32-bit", "sk","Mask of MAX_web_LocThk");
selectImage("sk");
run("Multiply...", "value=255");
run("Set Measurements...", "mean display nan redirect=[Result of sk] decimal=4"); // product of skeleton and local thickness
rename(img_name);
run("Analyze Particles...", "size=0-Infinity show=Nothing summarize");

close("*");
}

//Creat results table and save it
Table.create("Results_Widths");
img = Table.getColumn("Slice", "Summary");
mean_wd = Table.getColumn("Mean", "Summary");
Table.setColumn("Image", img, "Results_Widths");
Table.setColumn("Mean Width", mean_wd, "Results_Widths");
close("Summary");
selectWindow("Results_Widths");
saveAs("Measurements", output + File.separator + "Results_Widths.xls");
close("Results_Widths.xls");

print("Finish! Check your results at " + output + File.separator);
exit;
