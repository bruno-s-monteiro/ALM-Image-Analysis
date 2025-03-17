close("*");
print("\\Clear")
run("Clear Results");
roiManager("reset");
setBatchMode(true);

#@ File (label = "Input directory", style = "directory") input
#@ String (label = "File suffix", value = ".lif") suffix
#@ File (label = "Output directory", style = "directory") output

#@ Double (label="Cell Minimum Size", value=200.0) cyto_minimum_size
#@ Double (label="Nuclei Minimum Size", value=61.0) nuc_minimum_size
#@ Double (label="Proeminence for uNuclei detection", value=2500.0) unuc_pro

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
    
    for (k = 1; k <= seriesCount; k++) {
        run("Bio-Formats", "open=" + filePath + " autoscale color_mode=Default view=Hyperstack stack_order=XYCZT series_" + k);
        close("\\Others");
			fullName = getTitle();	
			fullName = replace(fullName, suffix, "");
			label = fullName + "_Series_" + k;
//Pre-processing of image before segmentation

        // Get image information and normalize the data name
        mainName = getTitle();        
        run("Duplicate...", "title=Image duplicate");
        close(mainName);
        
        selectWindow("Image");
        run("Split Channels");
        

        selectWindow("C1-Image");
        run("Subtract Background...", "rolling=" + bgRadius);
        run("Duplicate...", "title=C1-Image-DUP");    
        selectWindow("C2-Image");
        run("Subtract...", "value=" + bgAvg);
        run("Gaussian Blur...", "sigma=5");

        run("Merge Channels...", "c2=C2-Image c5=C1-Image create");  // Merge channels into a single composite image

//Segemntation of cell and nucleus
    
    //Detect nucleus
    selectWindow("C1-Image-DUP");
    run("Cellpose ...", "env_path=" + cellposeEnv + " env_type=" + envType + " model=" + nucModelDir + " model_path=" + nucModelDir + " diameter=" + nucleiDiameter + " ch1=" + ch1Nuc + " ch2=" + ch2Nuc + " additional_flags=--use_gpu"); 
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
	roiManager("Combine"); 	
	run("Create Mask");
	rename("Nuclei_Mask_Org");
	roiManager("reset");
	
	selectWindow("C1-Image-DUP-cellpose"); 
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
	        	run("Enlarge...", "enlarge=-3");
	        	roiManager("Update");     
	        	      }	        	      
	
	roiManager("Deselect");
	roiManager("Combine"); 	
	run("Create Mask");
	rename("Nuclei_Mask");
	roiManager("reset");    
	
	// Segment cytoplasm
    selectWindow("Composite");
    run("Cellpose ...", "env_path=" + cellposeEnv + " env_type=" + envType + " model=" + cytoModelDir + " model_path=" + cytoModelDir + " diameter=" + cytoModelDir + " ch1=" + ch1Cyto + " ch2=" + ch2Cyto + " additional_flags=--use_gpu");
    //close("Composite");
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
		roiManager("Deselect");

	//Count nucleus inside cell ROIs
	roiCount = roiManager("count");
					if (roiCount == 0) { //Safegard for no cells
						if (k == 1){
						Table.create("Results"); //If the firs image in a seir«es does not have cells creates a Results table 
							setResult("Label",0,label);
							setResult("Nuclei-Count",0,0);
							setResult("Micronuclei-Count",0,0); 
						} else {
						continue;
						}
   } else {
   	
	selectWindow("Nuclei_Mask");
	for (i = 0; i < roiCount; i++) {
	    roiManager("Select", i);
		run("Analyze Particles...", "exclude summarize");	
	}	
	IJ.renameResults("Summary", "Summary-Nuclei");	
	
				//Creates cytoplasm ROIs by removing nucleus ROIs from cell ROIs
				selectWindow("Nuclei_Mask_Org");
				
				nROIs = roiManager("count"); 
				for (i = 0; i < nROIs; i++) {
				    nROIs_1 = roiManager("count");
				    roiManager("Select", 0);
				    run("Analyze Particles...", "add"); 	
				    	nROIs_2 = roiManager("count"); 
				    if (nROIs_1 == nROIs_2) {    	
				    	roiManager("Select",0);
				    	roiManager("Delete")   	
				    } else {	  	
						empty_array = newArray(nROIs_2 - nROIs_1 + 1); 
						empty_array[0] = 0;
						// Populate the array with values from nROIs_1 to nROIs_2 
						for (j = nROIs_1; j < nROIs_2; j++) {
						    empty_array[j - nROIs_1 + 1] = j; // Store values in the empty_array
					}
					 	roiManager("select",empty_array);
					    roiManager("XOR");
						roiManager("Add");
						roiManager("Delete");					
					}
				}
   			
	//Count micronucleus inside cytoplasm ROIs
	selectWindow("C1-Image-DUP");	
	run("Median...", "radius=4");	
		roiCount_Cyto = roiManager("count"); 
			if (roiCount != roiCount_Cyto) { //Safegard for different results
					if (k == 1){
						Table.create("Results"); //If the firs image in a seir«es does not have cells creates a Results table 
							setResult("Label",0,label);
							setResult("Nuclei-Count",0,0);
							setResult("Micronuclei-Count",0,0); 
						} else {
						continue;
						}
   } else {
   	
	for (z = 0; z < roiCount_Cyto; z++) {
	    roiManager("Select", z);
	    run("Find Maxima...", "prominence=" + unuc_pro + " exclude output=Count");
	}
	IJ.renameResults("Results", "Summary-uNuclei");
	
	roiManager("reset");
	roiManager("deselect");

	//Create results table from two counts
    
	count = newArray(roiCount);
	count1 = Table.getColumn("Count", "Summary-Nuclei");
	count2 = Table.getColumn("Count", "Summary-uNuclei");
						
	run("Set Measurements...", "  redirect=None decimal=3");
	Table.create("Results");
		for (j=0; j<roiCount ; j++) {
			setResult("Label", j, label);
			setResult("Nuclei-Count", j, count1[j]);
			setResult("Micronuclei-Count", j, count2[j]);
		}
		
		close("Summary-Nuclei");
		close("Summary-uNuclei");				          
		
		}
   }   
   		close("*");
        
        //Saves output data
		data_name = substring(file, 0, file.length - 4);
		dir = output + "/" + data_name +  "_Counts.xlsx";	
   		
		run("Excel Macro Extensions", "debuglogging=false");
		if (k == 1) {
		Ext.xlsx_SaveAllTablesToWorkbook(dir, true);
		} else {
		Ext.xlsx_AppendTableAsRows("Results", dir, 0, false);
		}
        close("Results");
        
        }             			
    }

  print("Finished! Your Results are ready.");