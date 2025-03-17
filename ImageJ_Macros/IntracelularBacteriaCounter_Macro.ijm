/*
           __
           ||              # ADVANCED LIGHT MICROSCOPY - i3S
         ====
         |  |__            Bruno S. Monteiro (brunom@i3s.up.pt)
         |  |-.\           Maria Azevedo (maria.azevedo@i3s.up.pt)
         |__|  \\          Paula Sampaio (sampaio@i3s.up.pt)
          ||   ||         
        ======__|         **************************************************
       ________||__                 INTRACELULAR BACTERIA COUNTER
      /____________\      **************************************************                             
                                     Last updated: 21/10/24
       
**Requirements**

  - FIJI
  - Working installation of the PTBIOP plugin and Cellpose 3.0 (https://github.com/MouseLand/cellpose).
  - Python distribution, e.g Anaconda
  
**Input**
  - The macro is optimized for .lif files, but it can be adapted to other formats.
 
**Output**
  - A results table containing the count of bacteria per cell.
  - Processed image displaying the outlines of individual cells with marked bacterial structures and saves this image as a TIFF file in the specified output directory.

**Workflow Overview**
This macro processes multiple 3-channel images (Nuclei, Soma, Bacteria) to analyze intracellular bacteria (or similar small, round structures) within cells.

  1. The macro processes all images in a specified input directory.
  2. For each image series in the `.lif` file, Bio-Formats is used to load the data, and the image is duplicated for processing.
  3. The "Bacteria" channel undergoes background subtraction and Difference of Gaussians (DoG) filtering to highlight individual bacteria.
  4. Large bacterial clusters are identified and excluded from the analysis. The DoG-processed image is cleared of these clusters, leaving only individual bacteria for counting.
  5. The Cellpose 3.0 algorithm is employed to segment cell bodies (somas) using the "Soma" and "Nuclei" channels. The resulting segmented cells are converted to ROIs.
  6. Somas touching the image borders are excluded to ensure accurate counting.
  7. For each cell ROI, the macro counts the number of bacteria using a maxima detection method.

**Attribution**
 If you use this macro please in your papers and/or thesis (MSc and PhD) acknowledging the i3S Scientific Platforms involved in your work is encouraged (C.E. 17/07/2017). 
 For the acknowledgment to the ALM, please use one of the following sentences (as a reference):
 
     "The authors acknowledge the support of i3S Scientific Platform Advanced Light Microscopy, member of the national infrastructure PPBI-Portuguese Platform of BioImaging (supported by POCI-01-0145-FEDER-022122)."
     "The authors acknowledge the support of i3S Scientific Platform Advanced Light Microscopy, a site of PPBI Euro-Bioimaging Node"

 Please send us the reference of your published work involving our unit.
 
    If you use Cellpose 1, 2 or 3, please cite the Cellpose 1.0 paper:
	Stringer, C., Wang, T., Michaelos, M., & Pachitariu, M. (2021). Cellpose: a generalist algorithm for cellular segmentation. Nature methods, 18(1), 100-106.
		
	If you use the human-in-the-loop training, please also cite the Cellpose 2.0 paper:
	Pachitariu, M. & Stringer, C. (2022). Cellpose 2.0: how to train your own model. Nature methods, 1-8.
		
	If you use the new image restoration models or cyto3, please also cite the Cellpose3 paper:
	Stringer, C. & Pachitariu, M. (2024). Cellpose3: one-click image restoration for improved segmentation. bioRxiv. 


**Copyrights**
 All rights to the work developed by the ALM team are reserved. We kindly ask you not to transmit any information by any means without express permission from the author(s).

*///------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

close("*");
print("\\Clear")
run("Clear Results");
roiManager("reset");
// Speed up code execution by batching commands
setBatchMode(true);

//Process multiple images in a folder

#@ File (label = "Input directory", style = "directory") input
#@ File (label = "Output directory", style = "directory") output
#@ String (label = "File suffix", value = ".lif") suffix


#@ File (label = "Cellpose Environment directory", style = "directory") env_path
#@ String (label="Cellpose Environment Type", choices={"venv", "conda"}) env_type
#@ Integer (label="Channel 1 (ch1) for Cytoplasm", value=0) ch1
#@ Integer (label="Channel 2 (ch2) for Nucleus (use 0 for none)", value=0) ch2
#@ Double (label="Cell Diameter", value=30.0) cellDiameter

// Channel assignement
	
	// Define the options for the dropdown menus
	options = newArray("Nuclei", "Bacteria", "Soma");

	// Create a dialog to get user input for channel names with dropdown menus
	Dialog.create("Channel Names");
	Dialog.addChoice("Channel 1:", options, options[0]);
	Dialog.addChoice("Channel 2:", options, options[1]);
	Dialog.addChoice("Channel 3:", options, options[2]);
	Dialog.show();

	// Get the user-selected options
	channel1Name = Dialog.getChoice();
	channel2Name = Dialog.getChoice();
	channel3Name = Dialog.getChoice();
	
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

		print("Processing: " + file);
    
    for (j = 1; j <= seriesCount; j++) {
        // Open an image with Bio-Format
        run("Bio-Formats", "open=" + filePath + " autoscale color_mode=Default view=Hyperstack stack_order=XYCZT series_" + j);	

//Get image information and normalize the data name
fullName = getTitle();// Get the title of the image
    
    //Prepare output image by duplicating the original image
    run("Duplicate...", "duplicate");
    rename("Output");

    //Duplicate the image for further processing
    run("Duplicate...", "title=Image duplicate");
    close(fullName);

	//Split channels and rename them accordingly
	selectWindow("Image");
	run("Split Channels");

    // Rename channels based on user input
	selectWindow("C1-Image");
	rename(channel1Name);
	selectWindow("C2-Image");
	rename(channel2Name);
	selectWindow("C3-Image");
	rename(channel3Name);

//Pre-Processing the Bacteria channel
	selectWindow("Bacteria");
	run("Subtract Background...", "rolling=10");//background subtraction

	//Apply Difference of Gaussians (DoG) to highlight bacteria
		run("Duplicate...", "title=Bacteria_GB1 ignore");
		run("Duplicate...", "title=Bacteria_GB2 ignore");
	
	    selectWindow("Bacteria_GB1");
	    run("Gaussian Blur...", "sigma=1");
	
	    selectWindow("Bacteria_GB2");
	    run("Gaussian Blur...", "sigma=2");

	imageCalculator("Subtract create 32-bit", "Bacteria_GB1", "Bacteria_GB2");

	    selectWindow("Result of Bacteria_GB1");	
			fullName = replace(fullName, ".lif", "");
	    	rename(fullName + "_Count");

			close("Bacteria_GB1");
			close("Bacteria_GB2");

//Eliminate large clusters
	selectWindow("Bacteria");
	run("Duplicate...", "title=Bacteria_Clusters");

    selectWindow("Bacteria_Clusters");
    close("Bacteria");

	//Threshold clusters
	setAutoThreshold("Moments dark");
	//run("Threshold...");

	run("Analyze Particles...", "size=8-Infinity add");
	close("Bacteria_Clusters");

	selectWindow(fullName + "_Count");
	n = roiManager("count"); //Get the number of ROIs

    //Remove clusters from the DoG image
    for (i = 0; i < n; i++) {
        roiManager("Select", i); //Select each ROI individually
        run("Clear"); //Fill the selected ROI with black (0)
    }
 
roiManager("reset");
run("Select None");

//Mask somas using CellPose
	run("Merge Channels...", "c5=Nuclei c6=Soma create");
	selectWindow("Composite");

    run("Cellpose ...", "env_path="+env_path+" env_type="+env_type+" message= model=cyto3 message0= message1= model_path= diameter="+cellDiameter+" ch1="+ch1+" ch2="+ch1+" message2= additional_flags=--use_gpu message3=");
    selectImage("Composite-cellpose");
    run("Label image to ROIs", "rm=[RoiManager[size=145, visible=true]]"); // Extract ROIs of somas

	close("Composite");
	selectWindow(fullName + "_Count");
	roiManager("Show All");
	close("Composite-cellpose");

	//Exclude somas touching the borders
	getDimensions(width, height, channels, slices, frames);
		for (i = roiManager("count"); i > 0; i--) {
   			roiManager("select", i - 1);
    		getSelectionBounds(x, y, width1, height1);
    		if ((x == 0) || (y == 0) || ((x + width1) == width) || ((y + height1) == height)) 
        	roiManager("delete");
		}

//Count bacteria inside ROIs
	
		previousRowCount = nResults();
		
	for (i = roiManager("count"); i > 0; i--) {
    	roiManager("select", i - 1);
   	 	run("Find Maxima...", "prominence=400 output=Count");
		}
		
        //Adds the image name to its corresponding rows in the results table
		for (i = previousRowCount; i < nResults(); i++) {
		    setResult("Image i.d", i, fullName);
		}
		
		updateResults();

//Create and save the output image with ROIs and point selections
	for (i = roiManager("count"); i > 0; i--) {
    	roiManager("select", i - 1);
    	run("Find Maxima...", "prominence=400 output=[Point Selection]");
    	roiManager("Add");
		}

	selectWindow("Output");
	run("Split Channels");
	run("Merge Channels...", "c2=[C2-Output] c5=[C1-Output] c6=[C3-Output] create");
	roiManager("Show All");

	//Save ROIs of sogma segmentation
	//ROIFileName = output + File.separator + file + ".zip"
	//roiManager("Save", ROIFileName);

    //Burn ROIs and point selections into the output image
    for (i = roiManager("count"); i > 0; i--) {
        roiManager("select", i - 1);
        run("Add Selection...");
    }
    
	//Save the output image
	newFileName = output + File.separator + fullName + "_Processed" + ".tiff"; // Construct the new filename with the suffix
	saveAs("Tiff", newFileName); //Save the image as a TIFF file
	
close("*");
roiManager("reset");
    }

	file = replace(file, ".lif", "");
  saveAs("Results", output + File.separator + file + "_BacteriaCount_Results.xls");

}
	print("Finished! Your Results are ready.");