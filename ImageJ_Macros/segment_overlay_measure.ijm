/*
           __
           ||              # ADVANCED LIGHT MICROSCOPY - i3S
         ====
         |  |__            Bruno S. Monteiro (brunom@i3s.up.pt)
         |  |-.\           Maria Azevedo (maria.azevedo@i3s.up.pt)
         |__|  \\          Paula Sampaio (sampaio@i3s.up.pt)
          ||   ||         
        ======__|         **************************************************
       ________||__                     ROI Overlay Processor
      /____________\      **************************************************                             
       								Last updated: 10/07/25

Requirements

  - FIJI
  - ROI zip files (ImageJ format) corresponding to input images

Workflow Overview

This Fiji macro processes 2-channel images with associated ROI sets to generate overlay images and measure ROI areas.

1. The macro scans the selected input folder and its subfolders for images with the specified suffix.

2. For each image, it attempts to open a matching `.zip` file containing ROIs (Regions of Interest).

3. The image is pre-processed and thresholded to create a binary mask, which is saved for visualization.

4. ROIs are measured for area and area fraction, and optionally drawn on the original image using predefined colors.

5. An RGB overlay image is created by combining the mask and ROIs over the original signal.

6. Final overlay images are saved in PNG format, and the results table is saved as a `.csv` file.

Attribution

 If you use this macro in your work (e.g., MSc or PhD thesis, or publications), please acknowledge the i3S Scientific Platforms involved.

 Suggested acknowledgment for ALM:

     "The authors acknowledge the support of i3S Scientific Platform Advanced Light Microscopy, member of the national infrastructure PPBI-Portuguese Platform of BioImaging (supported by POCI-01-0145-FEDER-022122)."
     
     OR

     "The authors acknowledge the support of i3S Scientific Platform Advanced Light Microscopy, a site of PPBI Euro-Bioimaging Node."

 We kindly ask you to send us a reference to any publication or thesis involving this macro.

Copyrights

 All rights to this macro and its workflow are reserved to the ALM team. Do not distribute or modify without prior permission from the authors.
*/

roiManager("reset");
close("*");
print("\\Clear");
setBatchMode(true);

#@ File (label = "Input directory", style = "directory") input
#@ File (label = "Output directory", style = "directory") output
#@ String (label = "File suffix", value = ".tif") suffix

#@ String (label = "Set overlay image min", value = "30") min
#@ String (label = "Set overlay image max", value = "850") max
#@ String (label = "Set overlay mask opacity", value = "35") opacity

#@ String (label = "Select overlay color", choices = {"Red", "Green", "Blue", "Cyan", "Magenta", "Yellow"}) over_clr
#@ String (label = "Draw ROIs?", choices = {"Yes", "No"}) drw_rois
#@ String (label = "ROIs Line width", value = "6") width

processFolder(input);

// Function to recursively process folders
function processFolder(input) {
    list = getFileList(input);
    list = Array.sort(list);
    for (i = 0; i < list.length; i++) {
        path = input + File.separator + list[i];
        if (File.isDirectory(path)) {
            processFolder(path);
        } else if (endsWith(list[i], suffix)) {
            processFile(input, output, list[i]);
        }
    }
}

// Function to process each valid file
function processFile(input, output, file) {
    baseName = replace(file, suffix, ""); // remove suffix from filename
    zipName = baseName + ".zip"; 
    zipPath = input + File.separator + zipName;

    // Open main image
    open(input + File.separator + file);
    print("Opened image: " + file);

    // Check if the corresponding .zip file exists and open it
    if (File.exists(zipPath)) {
        open(zipPath); 
        print("Opened ROIs: " + zipName);
    } else {
        print("No .zip file found for: " + file);
    }

	title=getTitle();
	run("Duplicate...", "title=ch2_img duplicate channels=2");
	close(title);
	run("Duplicate...", "title=mask");
	
	// Image pre-processing
	run("8-bit");
	run("Subtract Background...", "rolling=150");
	run("Smooth");
	
	// Segmentation
	setAutoThreshold("RenyiEntropy dark no-reset");
	getThreshold(lower, upper);	
	adjusted = lower * 0.70; // calculate a new lower threshold (30% lower)
	setThreshold(adjusted, upper);
	setOption("BlackBackground", true);
	run("Convert to Mask");
	
	rename(baseName);
	
	// Measurement of Area%
	nregions = roiManager("count");
	for (k = 0; k < nregions ; k++) {
		run("Set Measurements...", "area area_fraction display redirect=None decimal=3");
		roiManager("Select", k);
		roiManager("Measure");	
	}	
	roiManager("Show None");
	
	// Make overlay image
	run(over_clr);
	selectImage("ch2_img");
	run("Grays");
	if (drw_rois == "Yes") { // If Yes ROIs outlines will be drawn using different colors
		roiManager("Show All without labels");
		colors = newArray("yellow", "cyan", "magenta", "blue", "red", "green"); // ROI colors
		for (k = 0; k < nregions ; k++) {
			roiManager("select", k);
			roiManager("Set Color", colors[k]);
			roiManager("Set Line Width", width);
			run("Add Selection...");
		}
	}
	
	roiManager("Show None");
	setMinAndMax(min, max);
	run("Add Image...", "image="+baseName+" x=0 y=0 opacity="+opacity+" zero"); // Segmented regions are drawn as a color overlay
	close(baseName);
	run("RGB Color");

	saveAs("PNG", output + File.separator + baseName + "_overlay.png");
	
	roiManager("reset");
	close("*");
}

saveAs("Results", output + File.separator + "Results.csv");
close("Results")
print("Finished. Results and overlays saved at: " + output);