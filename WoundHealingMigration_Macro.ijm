/*
           __
           ||              # ADVANCED LIGHT MICROSCOPY - i3S
         ====
         |  |__            Bruno S. Monteiro (brunom@i3s.up.pt)
         |  |-.\           Maria Azevedo (maria.azevedo@i3s.up.pt)
         |__|  \\          Paula Sampaio (sampaio@i3s.up.pt)
          ||   ||         
        ======__|         **************************************************
       ________||__           WOUND HEALING ASSAY FOR NON-CANCEROUS CELLS
      /____________\      **************************************************                             
                                   Last updated: 2/10/2024
       
**Requirements**
  - FIJI
  - Bio-Formats Plugin
  
**Input**
  - Brightfield timelapse of Wound healing assay
  
  Note: The macro is optimized for .lif files, but it can be adapted to other formats
 
**Output**
  - A results table containing the total area and % of area occupied at any given time point (slice)
  - A Tiff-converted timelapse of he binary mask resulting from the segemntation with the selected ROI overlayed   

**Workflow Overview**

1. **Input Parameters**
   - The user specifies the input directory, output directory, and file suffix (e.g., `.lif`).
   - A dialog box appears, asking the user to select algorithm parameters (Gaussian sigma, background radius, and thresholding algorithm).
2. **Processing Files**
   - The macro scans through the input directory for image files matching the provided suffix.
   - For each `.lif` file, Bio-Formats is used to open the image series.
3. **Image Preprocessing:**
   - A copy of the image is created, and illumination correction is performed by subtracting a Gaussian blurred image from the original.
   - Background subtraction and additional Gaussian blur are applied to the corrected image.
4. **Image Segmentation:**
   - The preprocessed image is thresholded based on the selected thresholding algorithm.
   - The image is then converted into a binary mask with objects set as 255 (white) and the background as 0 (black).
5. **Post-Processing**
   - Morphological operations (open) are applied to clean up the mask.
   - The user can manually check and adjust the Region of Interest (ROI).
6. **Particle Analysis**
   - The macro analyzes particles within the user-defined ROI and summarizes the results in a table.
7. **Saving Outputs**
   - The results are saved.

**Attribution**
	 If you use this macro please in your papers and/or thesis (MSc and PhD) acknowledging the i3S Scientific Platforms involved in your work is encouraged (C.E. 17/07/2017). 
	 For the acknowledgment to the ALM, please use one of the following sentences (as a reference):
	 
	   "The authors acknowledge the support of i3S Scientific Platform Advanced Light Microscopy, member of the national infrastructure PPBI-Portuguese Platform of BioImaging (supported by POCI-01-0145-FEDER-022122)."
	   "The authors acknowledge the support of i3S Scientific Platform Advanced Light Microscopy, a site of PPBI Euro-Bioimaging Node"
	
	 Please send us the reference of your published work involving our unit.

**Copyrights**
 	
 	All rights to the work developed by the ALM team are reserved. We kindly ask you not to transmit any information by any means without express permission from the author(s).

*///------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
//Reset output windows
close("*");
run("Clear Results");
print("\\Clear");
// Speed up code execution by batching commands
setBatchMode(true);

//Process multiple images in a folder

#@ File (label = "Input directory", style = "directory") input
#@ File (label = "Output directory", style = "directory") output
#@ String (label = "File suffix", value = ".lif") suffix

// Input parameters
		Dialog.create("Algorithm parameters");
		Dialog.addMessage("Select algorithm parameters");
		Dialog.addNumber("Gaussian sigma", 2);
		Dialog.addNumber("Backgroung radius", 20);
		items = newArray("IJ_IsoData","Huang","Otsu","Default");
		Dialog.addChoice("Threshold algorithm", items);
		Dialog.show();
		
		//Input variables
		sigma = Dialog.getNumber();
		radius = Dialog.getNumber();
		thres = Dialog.getChoice();

// Process the folder
processFolder(input);

function processFolder(input) {
    list = getFileList(input);
    list = Array.sort(list);
    for (i = 0; i < list.length; i++) {
        if (File.isDirectory(input + File.separator + list[i])) {
            processFolder(input + File.separator + list[i]);
        } else if (endsWith(list[i], suffix)) {
            processFile(input, output, list[i]);
        }
    }
}

function processFile(input, output, file) {
    // Build the full file path
    filePath = input + File.separator + file;

    run("Bio-Formats Macro Extensions");

    // Set up Bio-Formats to handle the current .lif file
    Ext.setId(filePath);
    Ext.getSeriesCount(seriesCount); // Get the number of image series in the active dataset.

    for (j = 1; j <= seriesCount; j++) {
        // Open an image with Bio-Format
        run("Bio-Formats", "open=" + filePath + " autoscale color_mode=Default view=Hyperstack stack_order=XYCZT series_" + j);

        //Get the name of the image (series) and print it
        fullName = getTitle();
        print("Processing: " + fullName);

//
run("Duplicate...", "title=Duplicate duplicate");
close(fullName);

//Illumination correction
	selectImage("Duplicate");
	run("Duplicate...", "title=Duplicate-GF duplicate");
	run("Gaussian Blur...", "sigma=12 stack");
	imageCalculator("Subtract create 32-bit stack", "Duplicate","Duplicate-GF");
	close("Duplicate");
	close("Duplicate-GF");

//Preprocessing
	run("Subtract Background...", "rolling=" + radius + " stack");
	run("Gaussian Blur...", "sigma=" + sigma + " stack");
	resetMinAndMax();
		
//Segmentation
	setAutoThreshold(thres + " dark");
		setOption("BlackBackground", false);
		getThreshold(lower, upper);
		setThreshold(lower, upper*1.05);
		
	run("Convert to Mask", "method=" + thres + " background=Dark calculate black");
    
//Post-processing
	run("Options...", "iterations=1 count=1 do=Open stack");

// Draw the ROI and analyse particles inside it
		
		setBatchMode(false);
		
    makeRectangle(776, 1400, 393, 2928);
    setBatchMode(true);
    waitForUser("Check segmentation and adjust the ROI position - Click OK to continue.");       	
	
	run("Analyze Particles...", "size=4-Infinity pixel summarize stack");
	run("Add Selection...");

//Save outputs
saveAs("Results", output + File.separator + fullName + "_Data.xls");
run("Close");

saveAs("Tiff", output + File.separator + fullName + "_Processed.tiff");
close("*");

	}
}

close("*");
print("Finished! Your Results are ready.");