/*
           __
           ||              # ADVANCED LIGHT MICROSCOPY - i3S
         ====
         |  |__            Bruno S. Monteiro (brunom@i3s.up.pt)
         |  |-.\           Maria Azevedo (maria.azevedo@i3s.up.pt)
         |__|  \\          Paula Sampaio (sampaio@i3s.up.pt)
          ||   ||         
        ======__|         **************************************************
       ________||__              CHANNEL MERGER FOR OPERETTA IMAGES
      /____________\      **************************************************                             
       
									Last updated: 11/10/2024       					       					
**Requirements**
  - FIJI
 
**Input**
  - Single channel images (ch1 or ch2) with the folowing name shceme "r0xcxxf0xp0x" where c is 0-9 
  
**Output**
  - Intensity adjusted RGB image
  
**Workflow Overview**

The code looks for images (single-channel c1 and c2) that share the same naming convention and sequentially processes them, applying intensity adjustments and merging the channels into a single RGB output.

**Attribution**
	 If you use this macro in your papers and/or thesis (MSc and PhD), please acknowledge the i3S Scientific Platforms involved in your work (C.E. 17/07/2017). 
	 For the acknowledgment to the ALM, please use one of the following sentences (as a reference):
	 
	   "The authors acknowledge the support of i3S Scientific Platform Advanced Light Microscopy, member of the national infrastructure PPBI-Portuguese Platform of BioImaging (supported by POCI-01-0145-FEDER-022122)."
	   "The authors acknowledge the support of i3S Scientific Platform Advanced Light Microscopy, a site of PPBI Euro-Bioimaging Node"
	
	Please send us the reference of your published work involving our unit.
	 
**Copyrights**
 All rights to the work developed by the ALM team are reserved. We kindly ask you not to transmit any information by any means without express permission from the author(s).

*/

// Reset 
close("*");
run("Clear Results");
roiManager("reset");
// Speed up code execution by batching commands
//setBatchMode(true);

dir = getDirectory("Choose a Input Directory");
outputDir = getDirectory("Choose the Output Directory");

#@ Double (label="Channel 1 Minimum Int Value", value=129) minCh1
#@ Double (label="Channel 1 Maximum Int Value", value=13200) maxCh1

#@ Double (label="Channel 2 Minimum Int Value", value=2000) minCh2
#@ Double (label="Channel 2 Maximum Int Value", value=11000) maxCh2

#@ Double (label="Rolling Ball Radius for Background", value=30) radius

list = getFileList(dir);

for(r = 4; r <= 9; r++) { 
	for (c = 2; c <= 10; c++) { 
	    for (x = 1; x <= 9; x++) { 
	        
	        for (i = 0; i < list.length; i++) {
	            filename = list[i];
	            
	            if (c < 10) {
                    c_val = "c0" + c;  
                } else {
                    c_val = "c10" ;  
                }
                
                if (filename.indexOf("r0" + r + c_val + "f0" + x) != -1) {
                    open(dir + filename);
	                
	            if (filename.indexOf("ch1") != -1) {
                    name = getTitle();                   
                    rename("CH1");
                    setMinAndMax(minCh1, maxCh1);
                    run("Apply LUT");
                } else if (filename.indexOf("ch2") != -1) {
                    rename("CH2");
                    setMinAndMax(minCh2, maxCh2);
                    run("Apply LUT");
					run("Subtract Background...", "rolling=" + radius);
}	                             
	       }          
        }
                                       
        // Process Images
        run("Merge Channels...", "c2=CH2 c5=CH1 create");
        run("Stack to RGB");
        close("Composite");
        
        //Save Images
        shortName = substring(name, 0 , 12);
        saveAs("Tiff", outputDir + shortName + ".tif");

        close("*");
       
    	}  
    }
 }
