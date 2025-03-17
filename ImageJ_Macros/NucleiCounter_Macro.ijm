/*
           __
           ||              # ADVANCED LIGHT MICROSCOPY - i3S
         ====
         |  |__            Bruno S. Monteiro (brunom@i3s.up.pt)
         |  |-.\           Maria Azevedo (maria.azevedo@i3s.up.pt)
         |__|  \\          Paula Sampaio (sampaio@i3s.up.pt)
          ||   ||         
        ======__|         **************************************************
       ________||__              NUCLEI COUNTER FOR MULTINUCLEAR CELLS
      /____________\      **************************************************                             
                                    Last updated: 21/10/2024
       
**Requirements**
  - FIJI
  - Working installation of the PTBIOP plugin and Cellpose 3.0 (https://github.com/MouseLand/cellpose).
  - Working installation of the plugin MorphoLibJ
  - Python distribution, e.g Anaconda
  
**Input**
  - 2-channel images (one channel for the cytoplasm and other for the nucleus)
  - Trained Cellpose models for segmentation of nucleus and cytoplasm 
  
  Note: Ensure that the diameter and channel values for Cellpose segmentation match precisely with those specified for each model in the Cellpose GUI. 
  		The macro is optimized for .lif files, but it can be adapted to other formats
 
**Output**
  - A results table containing the count of nuclei per cell.
  - A hyperstack of cellpose label images 

**Workflow Overview**

This macro processes multiple 2-channel images (one channel for nuclei, the other for cytoplasm) to quantify the number of nuclei per cell. The key steps are:

	1. Pre-processing: Processes `.lif` files from the input directory, splits each image into nuclei and cytoplasm channels, and pre-processes them by removing background.   
	2. Segmentation:
	   - Nuclei: Uses a Cellpose model to segment the nuclei and filters out small objects.
	   - Cytoplasm: Segments the cytoplasm, removing small regions and those touching the image borders.
	3. Analysis: Associates nuclei with corresponding cytoplasm ROIs, and counts the nuclei per cell.   
	4. Saving Outputs: The final results include a table of nuclei counts per cell, and labeled images of nuclei and cytoplasm.

**Attribution**
	 If you use this macro in your papers and/or thesis (MSc and PhD), please acknowledge the i3S Scientific Platforms involved in your work (C.E. 17/07/2017). 
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

*/
close("*");
run("Clear Results");
roiManager("reset");

//setBatchMode(true);

#@ File (label = "Input directory", style = "directory") input
#@ String (label = "File suffix", value = ".lif") suffix
#@ File (label = "Output directory", style = "directory") output

#@ Double (label="Cell Minimum Size", value=200.0) cyto_minimum_size
#@ Double (label="Nuclei Minimum Size", value=125.0) nuc_minimum_size

#@ Double (label="Background Average Value", value=250, persist=false) bgAvg
#@ Double (label="Radius for Background Subtraction", value=100, persist=false) bgRadius

#@ File (label = "Nucleus Model file", style = "file") nucModelDir
#@ File (label = "Cytoplasm Model file", style = "file") cytoModelDir
#@ File (label = "Cellpose Environment directory", style = "directory") cellposeEnv

#@ String (label="Cellpose Environment Type", choices={"venv", "conda"}) envType

#@ Integer (label="Channel 1 (ch1) for Nucleus Model", value=0) ch1Nuc
#@ Integer (label="Channel 2 (ch2) for Nucleus Model", value=0) ch2Nuc
#@ Integer (label="Channel 1 (ch1) for Cytoplasm Model", value=0) ch1Cyto
#@ Integer (label="Channel 2 (ch2) for Cytoplasm Model", value=0) ch2Cyto
#@ Double (label="Nuclei Diameter", value=17.0) nucleiDiameter
#@ Double (label="Cell Diameter", value=30.0) cellDiameter

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
    
    filePath = input + File.separator + file;

    run("Bio-Formats Macro Extensions");

    Ext.setId(filePath);
    Ext.getSeriesCount(seriesCount);   
    print("Processing: " + file);
	print("Total series count in the file is " + seriesCount);
    
    for (j = 1; j <= seriesCount; j++) {
        run("Bio-Formats", "open=" + filePath + " autoscale color_mode=Default view=Hyperstack stack_order=XYCZT series_" + j);
        close("\\Others");
			fullName = getTitle();	
			fullName = replace(fullName, ".lif", "");
			   
//Pre-processing of image before segmentation

       // Get image information and normalize the data name
        mainName = getTitle();        
        run("Duplicate...", "title=Image duplicate");
        close(mainName);
        
        selectWindow("Image");
        run("Split Channels");
        
        // Remove background from nucleus channel
        selectWindow("C1-Image");
        run("Subtract Background...", "rolling=" + bgRadius);
        run("Duplicate...", "title=C1-Image-DUP");

        // Remove unspecific signal from cytoplasmic channel    
        selectWindow("C2-Image");
        run("Subtract...", "value=" + bgAvg);
        run("Gaussian Blur...", "sigma=5");

        // Merge channels into a single composite image
        run("Merge Channels...", "c2=C2-Image c5=C1-Image create");

//Segemntation of cytoplasm and nucleus 
    
    //Detect nucleus
    selectWindow("C1-Image-DUP");
    run("Cellpose ...", "env_path=" + cellposeEnv + " env_type=" + envType + " model=" + nucModelDir + " model_path=" + nucModelDir + " diameter=" + nucleiDiameter + " ch1=" + ch1Nuc + " ch2=" + ch2Nuc + " additional_flags=--use_gpu"); 
    close("C1-Image-DUP"); 
    run("Label image to ROIs");
    
	   		//Filter by size
	    	n = roiManager("count"); 
			to_be_deleted = newArray(); 
	
			for (i = 0; i < n; i++) { 
	    		roiManager("Select", i); 
				getStatistics(area, mean, min, max, std, histogram);
	    	if (area <= nuc_minimum_size){
			to_be_deleted = Array.concat(to_be_deleted, i);
			}   
		}
			if (to_be_deleted.length > 0){
				roiManager("Select", to_be_deleted);
				roiManager("Delete");
			}
    
	roiManager("Deselect");
	   	
	   		roicount = roiManager("count");	
	   		for(i=0; i < roicount ; i++){
	        	roiManager("Select", i);
	        	run("Enlarge...", "enlarge=-2");
	        	roiManager("Update");     
	        	      }	        	      
	        	      
	roiManager("Deselect");
	roiManager("Combine"); 	
	run("Create Mask"); 
	roiManager("reset");  
  		 	
	// Segment cytoplasm
        selectWindow("Composite");
        run("Cellpose ...", "env_path=" + cellposeEnv + " env_type=" + envType + " model=" + cytoModelDir + " model_path=" + cytoModelDir + " diameter=" + cytoModelDir + " ch1=" + ch1Cyto + " ch2=" + ch2Cyto + " additional_flags=--use_gpu");
		close("Composite");
		run("Label image to ROIs");
		
			//Filter by size
	    	n = roiManager("count"); 
			to_be_deleted = newArray(); 
	
			for (i = 0; i < n; i++) { 
	    		roiManager("Select", i); 
				getStatistics(area, mean, min, max, std, histogram);
	    	if (area <= cyto_minimum_size){
			to_be_deleted = Array.concat(to_be_deleted, i);
			}   
		}
			if (to_be_deleted.length > 0){
				roiManager("Select", to_be_deleted);
				roiManager("Delete");
			}

		//Exclude somas touching the borders
		getDimensions(width, height, channels, slices, frames);
		for (i = roiManager("count"); i > 0; i--) {
   			roiManager("select", i - 1);
    		getSelectionBounds(x, y, width1, height1);
    		if ((x == 0) || (y == 0) || ((x + width1) == width) || ((y + height1) == height)) 
        	roiManager("delete");
		}

	//Count nucleus inside ROIs
	selectWindow("Mask");
	rename(fullName + "_Region_" + j);
	roiManager("Show All");
	run("Set Measurements...", "  redirect=None decimal=3");
	
	roiCount = roiManager("count");
	for (i = 0; i < roiCount; i++) {
	    roiManager("Select", i);
		run("Analyze Particles...", "size=0-Infinity pixel summarize"); 
	}
	
	 close();
	 roiManager("Deselect");
	 roiManager("reset");
	 
// Save the output image               	      	
		       	
			selectWindow("Composite-cellpose");		
			rename("Cyto-Cellpose");
			selectWindow("C1-Image-DUP-cellpose");
			rename("Nuclei-Cellpose");
		
		run("Images to Stack", "use");
		run("Stack to Hyperstack...", "order=xyczt(default) channels=2 slices=1 frames=1");

   newFileName = output + File.separator + fullName + "_Series_" + j + ".tiff"; 
   saveAs("Tiff", newFileName);
 
        close("*");
        
        }           
  			IJ.renameResults("Summary", "Results");
	        file = substring(file, 0, file.length - 4);
	        saveAs("Results", output + File.separator + file + "_Nuclei_Counts.csv" );
		        
		        NumberofRows=Table.size("Results");
				Table.deleteRows(0, NumberofRows-1, "Results");
				close("Results");				
    }

  print("Finished! Your Results are ready.");