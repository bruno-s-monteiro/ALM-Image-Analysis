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
       
       
**Requirements**
*
  - FIJI
  - TrackMate plugin installed
  
**Workflow Overview**

1. Image Preprocessing
   - The two-channel image is modified by swapping its dimensions and converting it into a timelapse with two frames, one for each channel.

2. Mask Creation
   - Apply thresholding to both channels to create masks, one per channel. These masks highlight the key regions of interest for each channel.

3. Timelapse Generation
   - Convert both masks into a timelapse with two frames, one for each mask.

4. Timelapse Merging
   - Merge the two timelapses into a single one with two channels: 
     - One channel for the original signal
     - One channel for the masks (from both frames).

5. Tracking with TrackMate
   - The TrackMate GUI opens for tracking. Follow these steps:
      1. Verify image calibration and click "Next."
      2. Select "Mask detector."
      3. Set channel 2 for segmentation.
      4. Skip thresholding and filtering for segmentation.
      5. Select LAP tracker.
      6. Set the appropriate max distance for tracking and ignore gap closing.
      7. Skip thresholding and filtering for tracks.
      8. Export the "Spots" as a .csv file.
      
**Attribution**
 If you use this macro please in your papers and/or thesis (MSc and PhD) acknowledging the i3S Scientific Platforms involved in your work is encouraged (C.E. 17/07/2017). 
 For the acknowledgment to the ALM, please use one of the following sentences (as a reference):
 
     "The authors acknowledge the support of i3S Scientific Platform Advanced Light Microscopy, member of the national infrastructure PPBI-Portuguese Platform of BioImaging (supported by POCI-01-0145-FEDER-022122)."
     "The authors acknowledge the support of i3S Scientific Platform Advanced Light Microscopy, a site of PPBI Euro-Bioimaging Node"

 Please send us the reference of your published work involving our unit.

**Copyrights**
 All rights to the work developed by the ALM team are reserved. We kindly ask you not to transmit any information by any means without express permission from the author(s).

*///------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

// Reset output windows
run("Clear Results");
roiManager("reset");

// Get image information and normalize the data name

title = getTitle();
run("Duplicate...", "title=Signal_Stack duplicate channels=1-2");
close(title);

run("Duplicate...", "title=Bacteria_Mask duplicate");

selectWindow("Signal_Stack");

run("Re-order Hyperstack ...", "channels=[Frames (t)] slices=[Slices (z)] frames=[Channels (c)]");
run("Enhance Contrast", "saturated=0.35");

//Create Mask Channel for TrackMate segmentation

selectImage("Bacteria_Mask");
run("Split Channels");

	//Create Mask for Channel 1
	
	selectImage("C1-Bacteria_Mask");
	run("Subtract Background...", "rolling=20");
	
	setAutoThreshold("Otsu dark");
	//run("Threshold...");
	run("Convert to Mask");
	run("Analyze Particles...", "size=0.80-Infinity exclude add");

	roiManager("Select All");
	roiManager("Combine");

	run("Create Mask");// Create a mask for the combined ROI
	rename("Mask_CH1");
	close("C1-Bacteria_Mask")

	// Repeat process for Channel 2

	roiManager("reset");
	selectImage("C2-Bacteria_Mask");
	run("Subtract Background...", "rolling=20");
	
	setAutoThreshold("Otsu dark");
	//run("Threshold...");
	run("Convert to Mask");
	run("Analyze Particles...", "size=0.80-Infinity exclude add");
	
	close("C2-Bacteria_Mask");
	roiManager("Select All");
	roiManager("Combine");
	
	run("Create Mask");// Create a mask for the combined ROI
	rename("Mask_CH2");
	roiManager("reset");
	
// Creates a Timelapse of both Channel Images

run("Images to Stack", "name=Mask_Stack use");
run("16-bit");

// Merge the two stacks into a multi-channel image
run("Merge Channels...", "c1=Signal_Stack c2=Mask_Stack create keep");

rename("Track_"+title)
close("Mask_Stack")
close("Signal_Stack")

//Open trackmate
run("TrackMate");



