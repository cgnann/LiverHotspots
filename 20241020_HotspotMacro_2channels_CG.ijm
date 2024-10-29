// Author: Christian Gnann

// ImageJ Macro 

//load all tif files in the folder except for the overlay
//Once all images from the same field of view are loaded - merge them and convert to 8 bit
//loop through all channels, for each of the channels there will be two pop up windows
//First you will define the threshold  as you have done before
//then input this value into the second pop up window
//Annotate the hotspot area using the drawing tool in FiJi - there will be another pop up window 
// pop up window to adjust the staining intensities
//save composite and single-channel images with a scale bar
//perform the measurements on the raw intensities for all three channels in the hotspot and the rest of the image (min/max, mean, median intensity as well as the area and the fraction of the area covered  by pixels >0 
//Annotate the rows in the results table with channel and type of measurement (raw or binary)
//Apply threshold that you defined previously and measure the binarized pixel values for all channels (same as above)
//Save the binarized images (again including the hotspot annotation
//save the results table

// just some parameters
delimiter = "."; 
suffix = ".tif";
nChannels = 3;
ch_m1 = 1;
ch_m2 = 2;
ch_dapi = 3;

// Asks for input directory first
input = getDirectory("Input directory"); // specify where the images are located --> pop up window
// Asks for output directory second
output = getDirectory("Output directory"); // specify where the results should be saved

// pop up window that will allow you to rename the output file accoring to the condition used 
condition = getString("Set a condition that you will use for saving; e.g. 1hpi_CD3_CD8","");
// pop up window that will allow you to input the markers in the images
marker1 = getString("Provide marker 1; e.g. CD3","");

processFolder(input);
print("Finished Processing");

// clear results from previous measurements as well as potential ROIs
run("Clear Results"); //cleans all possible mesaurements from previous analysis
if (isOpen("ROI Manager")) {  //closes rpi manager and removes areas of interest from previous analysis
	selectWindow("ROI Manager");
	run("Close");
}

// function to scan folders/subfolders/files to find files with correct suffix --> i.e. all the images in the folder
function processFolder(input) {
	list = getFileList(input);
	list = Array.sort(list);
	for (i = 0; i < list.length; i++) {
		if(File.isDirectory(input + File.separator + list[i]))
			processFolder(input + File.separator + list[i]);
		if(endsWith(list[i], suffix))
			processFile(input, output, list[i]);	
	}
}

// actual run function
function processFile(input, output, file) {
	// open the image
	original_filename = input + file;
    filewosuffix = replace(file, suffix, "");
    print("Processing: " + original_filename);
    print("The filewosuffix is: "+filewosuffix);
    open(original_filename);
    if(matches(original_filename, ".*overlay_.*")){ //close the image if it is the overlay
		close();
    }
    
    if (isOpen("ROI Manager")) {  //closes rpi manager and removes areas of interest from previous analysis
		selectWindow("ROI Manager");
		run("Close");
	}
	
	// when all three channels are open we start processing the image
    if(endsWith(filewosuffix, "ch01")) {
		// get useful information from the filename
		indexOfChannel = indexOf(filewosuffix, "_ch");
		filewochannel = substring(filewosuffix, 0, indexOfChannel); // get the filename wo channel to be able to merge the images
		img_number = substring(filewochannel, lengthOf(filewochannel) - 1, lengthOf(filewochannel));
		
		// create a composite image (RGB)
		run("Merge Channels...", "c1="+filewochannel + "_ch00.tif c2="+filewochannel + "_ch01.tif create"); // change the channels and colors if you want

    	// convert to 8 bit
    	setOption("ScaleConversions", true);
		run("8-bit");
		
		// Now let's set the threshold (channel 1 first)
		run("Duplicate...", "title=marker1 duplicate channels=1");
		run("Grays");
		waitForUser("Adjust the thresshold and remember the number");
		ch1_low = getNumber("Input the threshold for channel 1; e.g. 13",0);
		close(); // close the current image and repeat for the other channels
		// Now let's set the threshold (channel 2)
		run("Duplicate...", "title=marker2 duplicate channels=2");
		run("Grays");
		waitForUser("Adjust the thresshold and remember the number");
		ch2_low = getNumber("Input the threshold for channel 2; e.g. 13",0);
		close();
		
		// initialize a list to store all the thresholds
		threshold_list = newArray(ch1_low, ch2_low); 
		
		// define hotspot and control areas by manually drawing a region - based on dapi staining only
		run("Duplicate...", "title=marker3 duplicate channels=2");
		//setTool("freehand");
		waitForUser("define hotspot region");
		roiManager("Add");
		run("Make Inverse");
		roiManager("Add");
		roiManager("Select", 0);
		roiManager("Rename", "hotspot_img" + img_number);
		roiManager("Select", 1);
		roiManager("Rename", "control_img" + img_number);
		close();
		
		// save images with the hotspot annotation and scale bar
		run("Duplicate...", "duplicate"); //generates duplicate of current composite
		// change color for saving --> DAPI to blue
		Stack.setChannel(2);
		run("Blue");
		run("Scale Bar...", "width=50 height=[0] thickness=30 font=50 color=White background=None location=[Lower Right] horizontal bold overlay");
		waitForUser("Adjust the brightness and contrast for visualization"); //// adjust contrast & brightness 
		// add the hotspot annotation to the image
		roiManager("Select", 0);
		roiManager("Set Color", "white");
		roiManager("Set Line Width", 10);
		run("Add Selection...");  
		// now save the composite and individual channels
		saveAs("PNG", output+ filewochannel + "_composite" + ".png"); //saves all three channels
		//get individual images
		Stack.setActiveChannels("01");
		saveAs("PNG", output+ filewochannel + "_DAPI" + ".png"); //saves only the 3rd channel (DAPI)
		Stack.setActiveChannels("10");
		saveAs("PNG",output+ filewochannel + "_" + marker1 + ".png");  //saves only the first channel
		close(); /// closes the duplicate
		
		// Now measure all three channels
		run("Set Measurements...", "area mean median area_fraction display redirect=None decimal=3");
		// select the two regions for measurement
		roiManager("Select", newArray(0,1));
		Stack.setDisplayMode("grayscale");
		//for each channel perform the measurement and update the results table with "channel" and "MeasurementType" --> raw
		for (ch = 1; ch <= 2; ch++) {
		    Stack.setChannel(ch);         // Set the current channel
		    roiManager("Measure");        // Measure the ROI
		    setResult("Channel", nResults-1, ch);
		    setResult("Channel", nResults-2, ch);
		    setResult("MeasurementType", nResults-1, "Raw");
		    setResult("MeasurementType", nResults-2, "Raw");  // Add 'Raw' to the 'ImageType' column
		    setResult("region", nResults-1, "Encompassing tissue");
		    setResult("region", nResults-2, "IHS");
		    setResult("filename", nResults-1, filewochannel);
		    setResult("filename", nResults-2, filewochannel);
		}

		// Now the same for the binary images
		for (ch = 1; ch <= 2; ch++) {
		    Stack.setChannel(ch);
		    // threshold function - as done in the previous version using the thresholds defined earlier
		    setAutoThreshold("Default no-reset");
			run("Threshold...");
			setThreshold(threshold_list[ch-1], 255);    // get the corresponding threshold from the threshold list 
			run("Convert to Mask", "method=Default background=Dark only");
			roiManager("Measure");
		    // add channel and measurment type to the results table
		    setResult("Channel", nResults-1, ch);
		    setResult("Channel", nResults-2, ch);
		    setResult("MeasurementType", nResults-1, "Binary");  // Add 'Raw' to the 'ImageType' column
		    setResult("MeasurementType", nResults-2, "Binary");  // Add 'Raw' to the 'ImageType' column
			setResult("region", nResults-1, "Encompassing tissue");
		    setResult("region", nResults-2, "IHS");
		    setResult("filename", nResults-1, filewochannel);
		    setResult("filename", nResults-2, filewochannel);
		}
		
		// saving the binarized images
		Stack.setDisplayMode("composite");
		// change color for saving --> DAPI to blue
		Stack.setChannel(2);
		run("Blue");
		run("Scale Bar...", "width=50 height=[0] thickness=30 font=50 color=White background=None location=[Lower Right] horizontal bold overlay");
		// add the hotspot annotation to the image
		roiManager("Select", 0);
		roiManager("Set Color", "white");
		roiManager("Set Line Width", 10);
		run("Add Selection...");
		// now save the binary images
		saveAs("PNG", output+ "binary"+ "_" + filewochannel + "_composite.png");
		Stack.setActiveChannels("10");
		saveAs("PNG",output+ "binary"+ "_" + filewochannel + "_" + marker1 + ".png");
		Stack.setActiveChannels("01");
		saveAs("PNG",output+ "binary"+ "_" + filewochannel + "_" + "DAPI" + ".png");
    }
    saveAs("Results", output+  condition + "_measurement.csv");
   	
}
// to prevent running out of memory
run("Close All"); 
call("java.lang.System.gc");