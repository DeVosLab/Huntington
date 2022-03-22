/*	BIL_Huntinton_2D_v9.ijm
	-----------------------
	Author: 			Marlies Verschuuren -- marlies.verschuuren@uantwerpen.be
						Building Blocks -- Winnok H. De Vos: CellBlocks_v12.ijm -- winnok.devos@uantwerpen.be
	Date Created: 		2020 - 07 - 07
	Date Last Modified:	2022 - 02 - 08
*/

/*  Plugins needed (Help > Update > Manage update sites):
 	Bio-Formats: https://sites.imagej.net/Bio-Formats/
	ImageScience: https://sites.imagej.net/ImageScience/
	Stardist: https://sites.imagej.net/StarDist/
	CSBDeep: https://sites.imagej.net/CSBDeep/
*/

/* 	VERSION SUPPORT: 
	V1:	- Nuclei, vessel and spot segmentation 
			+ morphotextural measurements in all channels
			+ overlap with Marker+ mask
			
	V2:	- Spot segmentation: circularity filter
		- Measurements for each channel mask
		.1: Fix bug export mvd2 files 

	V3: - Nuclei segmentation on substacks

	V4: - Substacks with slides in between
		- Median filter nuclei
		- Multi scale vessel detection
		- Max finding in spot detection
		
	v5: - Include spot detection in region vessel 
		- Include measure region around nuclei
		- Diameter estimation vessel

	v6: - Multi-scale vessel detection: No multiplication with index

	v7: - Option multi-scale spot segmentation and max finding spot detection

	v8: - Add action tools and validation tools to test settings nuclei, spot and marker detection
		- Measure channel intensities
		
	v9: - Add index to log verification stack
		- Add length as parameter for vessel exclusion
		-.2 Fix bug loading verification stacks
*/  

//------------------------- Variables -------------------------//
//General --------------
var dirInput	= "";
var dirOutput	= "";
var suffix 		= ".tif";
var order		= "xyczt(default)";							
var micron		= getInfo("micrometer.abbreviation");		// 	micro symbol
var threshMethods 	= getList("threshold.methods");
var threshMethods 	= Array.concat(threshMethods,"Fixed");	
var filetypes 		= newArray(".tif",".tiff",".nd2",".ids",".jpg",".mvd2",".czi");	
var dimensions		= newArray("xyczt(default)","xyctz","xytcz","xytzc","xyztc","xyzct");
var filters 		= newArray("Median","Gaussian");

//Settings -------------
var pixelSize 	= 0.1785703;
var imgWidth	= 1000;
var imgHeight	= 1000;
var nChannels 	= 4;
var chNuc 		= 1; 
var chMarker1	= 2;
var chMarker2	= 3;
var chSpot		= 4;
var bg			= true;
var zproj		= true;
var bgRadius 	= 100;

//Mask ids
var idOriginal		= -100;
var idMax			= -100;
var idSubMax		= -100;
var idMaskMarker1    = -100;
var idMaskMarker2    = -100;
var idMaskNuclei	= -100;
var idMaskSpots		= -100;
var idMaskExclude	= -100;
var idMaskCell		= -100;

//Nuclei detection
var claheNuc	= true;
var filterNuc 		= "Gaussian";
var filterNucScale 	= 8; 
var probNuc			= 0.70;
var overlapNuc		= 0.40;
var minAreaNuc		= 25;
var maxAreaNuc 		= 250;
var minCircNuc		= 0.8;

//Cytoplasm detection
var itCellMicron 	= 5;
var exclude_nuclei 	= true;

//Spot detection
var multiScaleSpot 	= true;
var maxFindingSpot 	= true
var minScaleSpot 	= 1;
var maxScaleSpot 	= 4;
var threshSpot		= 30;
var minAreaSpot 	= 0.2;
var maxAreaSpot		= 6;
var minCircSpot 	= 0.6;

var excludeVesselStructures = true;
var gausExclude 			= 2;
var tubeExclude 			= true;
var minScaleExclude 		= 0.5;
var maxScaleExclude  		= 4;
var threshExclude  			= "Fixed";	
var threshExcludeFix  		= 0.15;
var minAreaExclude  		= 50;
var minVesselLengthExclude	= 15;

//Marker 1 detection
var gausMarker1 			= 2;
var tubeMarker1 			= true;
var minScaleTubeMarker1 	= 0.5;
var maxScaleTubeMarker1 	= 4;
var threshMarker1 			= "Fixed";	
var threshMarker1Fix 		= 0.15;
var minAreaMarker1 			= 50;

//Marker 2 detection
var gausMarker2				= 2;
var tubeMarker2				= true;
var minScaleTubeMarker2 	= 0.5;
var maxScaleTubeMarker2 	= 4;
var threshMarker2 			= "Fixed";	
var threshMarker2Fix 		= 0.2;
var minAreaMarker2 			= 50;

//------------------------- Macro -------------------------//
macro "[I] Install Macro"{
	// Only works on my personal drive 
	run("Install...", "install=[/data/CBH/mverschuuren/ACAM/CF-BIL_TamaraVasilkovska/200401_Huntington/GitHub/Huntington/BIL_Huntington_2D_v9.ijm]");
}

macro "Split Files Action Tool - Cf88 R0077 C888 R9077 R9977 R0977"{
	setBatchMode(true);
	splitRegions();
	setBatchMode("exit and display");
}

macro "Setup Regions Action Tool - C888 T5f16S"{
	setup();
}

macro "Segment Nuclei Action Tool -C999 H11f5f8cf3f181100 C999 P11f5f8cf3f18110 Ceee V5558"{
	erase(0);
	setBatchMode(true);

	//Get image id and title
	id 	= getImageID;
	title = getTitle; 
	prefix = substring(title,0,lastIndexOf(title,suffix));
	
	//Get directory
	dirInput = getInfo("image.directory");
	dirMax = dirInput+"Max"+File.separator;
	dirSubMax = dirInput+"SubMax"+File.separator;
	dirOutput = dirInput+"Output"+File.separator;
	if(!File.exists(dirMax)){
		print("No Max Projections Found. Run 'SplitAction' Tool");
	}
	if(!File.exists(dirSubMax)){
		print("No SubMax Projections Found. Run 'SplitAction' Tool");
	}
	if(!File.exists(dirOutput)){
		File.makeDirectory(dirOutput);
	}

	//Select substack
	nrSub  = getNumber("Nr Substack",3);
	
	//Open substack
	name=prefix+"_"+nrSub;
	print("Image: "+name);
	path=dirSubMax+"SubMax_"+name+".tif";
	open(path);
	idSubMax=getImageID();
	getPixelSize(unit, pixelWidth, pixelHeight);
	if(unit!=micron){
		run("Properties...", " unit="+micron+" pixel_width="+pixelSize+" pixel_height="+pixelSize);
	}else{
		pixelSize = pixelWidth;
	}

	//NucleiDetection
	countNuc = segmentationNuclei2D(idSubMax,name); 
	if(countNuc>0){
		countCell = segmentationCell2D(name);
	}

	//Visualisation
	selectImage(idSubMax);
	if(File.exists(dirOutput+name+"_CH"+chNuc+"_ROI_Cell.zip")){
		roiManager("Open",dirOutput+name+"_CH"+chNuc+"_ROI_Cell.zip");
		countCell=roiManager("count");
		roiManager("Set Color", "yellow");
		roiManager("Show All without labels");
	}
	if(File.exists(dirOutput+name+"_CH"+chNuc+"_ROI_Nuc.zip")){
		roiManager("Open",dirOutput+name+"_CH"+chNuc+"_ROI_Nuc.zip");
		countNuc=roiManager("count")-countCell;
		for(i=0; i<countNuc; i++){
			roiManager("Select", countCell+i);
			roiManager("Set Color", "cyan");
		}
		roiManager("Show All without labels");
	}

	selectImage(idMaskNuclei); close();
	selectImage(idSubMax);
	Stack.setChannel(chNuc);
	setBatchMode("exit and display");
	run("Tile");
}
macro "Spot Detection Action Tool - C999 H11f5f8cf3f181100 C999 P11f5f8cf3f18110 Ceee V3633 V4b33 V7633 Va933"{	
	erase(0);
	setBatchMode(true);
	
	//Get image id and title
	id 	= getImageID;
	title = getTitle; 
	prefix = substring(title,0,lastIndexOf(title,suffix));
	
	//Get directory
	dirInput = getInfo("image.directory");
	dirMax = dirInput+"Max"+File.separator;
	dirSubMax = dirInput+"SubMax"+File.separator;
	dirOutput = dirInput+"Output"+File.separator;
	if(!File.exists(dirMax)){
		print("No Max Projections Found. Run 'SplitAction' Tool");
	}
	if(!File.exists(dirSubMax)){
		print("No SubMax Projections Found. Run 'SplitAction' Tool");
	}
	if(!File.exists(dirOutput)){
		File.makeDirectory(dirOutput);
	}

	//Select substack
	nrSub  = getNumber("Nr Substack",3);
	
	//Open substack
	name=prefix+"_"+nrSub;
	print("Image: "+name);
	path=dirSubMax+"SubMax_"+name+".tif";
	open(path);
	idSubMax=getImageID();
	getPixelSize(unit, pixelWidth, pixelHeight);
	if(unit!=micron){
		run("Properties...", " unit="+micron+" pixel_width="+pixelSize+" pixel_height="+pixelSize);
	}else{
		pixelSize = pixelWidth;
	}

	//Spot detection
	countSpots = segmentationSpots2D(idSubMax,name,true);

	//Visualisation
	if(File.exists(dirOutput+name+"_CH"+chSpot+"_ROI.zip")){
		roiManager("Open",dirOutput+name+"_CH"+chSpot+"_ROI.zip");
	}
	selectImage(idMaskSpots); close();
	selectImage(idSubMax);
	Stack.setChannel(chSpot);
	roiManager("Show All without labels");
	setBatchMode("exit and display");
	run("Tile");
}

macro "Segment Markers Action Tool -C999 Hff1f1cfcff00"{
	erase(0);
	setBatchMode(true);

	//Get image id and title
	id 	= getImageID;
	title 	= getTitle; 
	prefix = substring(title,0,lastIndexOf(title,suffix));
	getPixelSize(unit, pixelWidth, pixelHeight);
	if(unit!=micron){
		run("Properties...", " unit="+micron+" pixel_width="+pixelSize+" pixel_height="+pixelSize);
	}else{
		pixelSize = pixelWidth;
	}
	
	//Get directory
	dirInput = getInfo("image.directory");
	dirMax = dirInput+"Max"+File.separator;
	dirSubMax = dirInput+"SubMax"+File.separator;
	dirOutput = dirInput+"Output"+File.separator;
	if(!File.exists(dirMax)){
		print("No Max Projections Found. Run 'SplitAction' Tool");
	}
	if(!File.exists(dirSubMax)){
		print("No SubMax Projections Found. Run 'SplitAction' Tool");
	}
	if(!File.exists(dirOutput)){
		File.makeDirectory(dirOutput);
	}

	//get SubStack
	nrSub  = getNumber("Nr Substack (0 = Max Proj. entire stack)",0);

	//Open Image
	if(nrSub==0){
		name=prefix;
		path=dirMax+"Max_"+name+".tif";
		open(path);}
	else {
		name=prefix+"_"+nrSub;
		path=dirSubMax+"SubMax_"+name+".tif";
		open(path);
	}
	idProj=getImageID();
	getPixelSize(unit, pixelWidth, pixelHeight);
	if(unit!=micron){
		run("Properties...", " unit="+micron+" pixel_width="+pixelSize+" pixel_height="+pixelSize);
	}else{
		pixelSize = pixelWidth;
	}

	//Detection
	idMaskMarker1 = segmentationMask2D (idProj,name,chMarker1,gausMarker1,tubeMarker1,minScaleTubeMarker1, maxScaleTubeMarker1,threshMarker1,threshMarker1Fix, minAreaMarker1,false,true);
	idMaskMarker2 = segmentationMask2D (idProj,name,chMarker2,gausMarker2,tubeMarker2,minScaleTubeMarker2, maxScaleTubeMarker2,threshMarker2,threshMarker2Fix, minAreaMarker2,false,true);

	//Visualisation
	roiManager("reset");
	if(File.exists(dirOutput+name+"_CH"+chMarker1+"_ROI.zip")){
		roiManager("Open",dirOutput+name+"_CH"+chMarker1+"_ROI.zip");
		currentCount=roiManager("count");
		roiManager("Select", (currentCount-1));
		roiManager("Set Color", "green");
		roiManager("Show All without labels");
	}
	print(dirOutput+name+"_CH"+chMarker2+"_ROI.zip");
	if(File.exists(dirOutput+name+"_CH"+chMarker2+"_ROI.zip")){
		roiManager("Open",dirOutput+name+"_CH"+chMarker2+"_ROI.zip");
		currentCount=roiManager("count");
		roiManager("Select", (currentCount-1));
		roiManager("Set Color", "RED");
		roiManager("Show All without labels");
	}
	selectImage(idProj);
	Stack.setChannel(chMarker1);

	if(File.exists(dirOutput+name+"_CH"+chMarker1+"_ROI.zip") || File.exists(dirOutput+name+"_CH"+chMarker2+"_ROI.zip")){
		roiManager("Show All without labels");
		run("From ROI Manager");
	}
	selectImage(idMaskMarker2); close();
	selectImage(idMaskMarker1); close();
	setBatchMode("exit and display");
}

macro "Analyse Single Image Action Tool - C888 T5f161"{
	start = getTime();
	run("ROI Manager...");
	setBatchMode(true);
	setOptions();
	
	//Get Directory
	dirInput = getInfo("image.directory");
	dirMax = dirInput+"Max"+File.separator;
	dirSubMax = dirInput+"SubMax"+File.separator;
	dirOutput = dirInput+"Output"+File.separator;

	if(!File.exists(dirMax)){
		print("No Max Projections Found. Run 'SplitAction' Tool");
	}
	if(!File.exists(dirSubMax)){
		print("No SubMax Projections Found. Run 'SplitAction' Tool");
	}
	if(!File.exists(dirOutput)){
		File.makeDirectory(dirOutput);
	}

	//Get Image Properties	
	title = getTitle; 
	prefix = substring(title,0,lastIndexOf(title,suffix));
	idOriginal = getImageID;
	selectImage(idOriginal);
	imgWidth = getWidth();
	imgHeight = getHeight();


	//Open image
	path=dirMax+"Max_"+prefix+".tif";
	open(path);
	idMax=getImageID();
	getPixelSize(unit, pixelWidth, pixelHeight);
	if(unit!=micron){
		run("Properties...", " unit="+micron+" pixel_width="+pixelSize+" pixel_height="+pixelSize);
	}else{
		pixelSize = pixelWidth;
	}

	//Intensity measurements
	selectImage(idMax);
	run("Select All");
	run("Set Measurements...", "mean standard min redirect=None decimal=2");
	run("Clear Results");
	for(c=1; c<=nChannels;c++){
		selectImage(idMax);
		Stack.setChannel(c);
		run("Measure");
	}
	saveAs("Measurements",dirOutput+prefix+"_ChannelInt.txt");
	run("Clear Results");

	//Marker Detection
	idMaskMarker1 = segmentationMask2D (idMax,prefix,chMarker1,gausMarker1,tubeMarker1,minScaleTubeMarker1, maxScaleTubeMarker1,threshMarker1,threshMarker1Fix, minAreaMarker1,true,true);
	selectImage(idMaskMarker1);
	rename("maskMarker1");
	idMaskMarker2 = segmentationMask2D (idMax,prefix,chMarker2,gausMarker2,tubeMarker2,minScaleTubeMarker2,maxScaleTubeMarker2,threshMarker2,threshMarker2Fix, minAreaMarker2,false,true);
	selectImage(idMaskMarker2);
	rename("maskMarker2");

	//Analyze masks
	analyzeMasks(idMax,idMaskMarker1,prefix,chMarker1);
	analyzeMasks(idMax,idMaskMarker2,prefix,chMarker2);

	//Visualisations
	selectImage(idMax);
	for(c=1; c<=nChannels; c++){
		if(File.exists(dirOutput+prefix+"_CH"+c+"_ROI.zip")){
			roiManager("Open",dirOutput+prefix+"_CH"+c+"_ROI.zip");
			currentCount=roiManager("count");
			roiManager("Select", (currentCount-1));
			if(c==chNuc){
				roiManager("Set Color", "cyan");
			}else if(c==chMarker1){
				roiManager("Set Color", "green");
			}else if(c==chMarker2){
				roiManager("Set Color", "red");
			}else if(c==chSpot){
				roiManager("Set Color", "magenta");
			}
			roiManager("Show All without labels");
		}
	}
	run("From ROI Manager");
	selectImage(idMaskMarker2); close();
	selectImage(idMaskMarker1); close();

	//Analysis substacks
	it=1;
	while(File.exists(dirSubMax+"SubMax_"+prefix+"_"+it+".tif")){
		name=prefix+"_"+it;
		print("--Analysis Substack: "+it);
		path=dirSubMax+"SubMax_"+name+".tif";
		open(path);
		getStatistics(area, mean, min, max, std, histogram);
		//Run if standard deviation of intensities > 2
		if(std>2){
			//Image properties
			idSubMax=getImageID();
			getPixelSize(unit, pixelWidth, pixelHeight);
			if(unit!=micron){
				run("Properties...", " unit="+micron+" pixel_width="+pixelSize+" pixel_height="+pixelSize);
			}else{
				pixelSize = pixelWidth;
			}

			//Marker detection
			idMaskMarker1 = segmentationMask2D (idSubMax,name,chMarker1,gausMarker1,tubeMarker1,minScaleTubeMarker1, maxScaleTubeMarker1,threshMarker1,threshMarker1Fix, minAreaMarker1,false,true);
			selectImage(idMaskMarker1);
			rename("maskMarker1");
			idMaskMarker2 = segmentationMask2D (idSubMax,name,chMarker2,gausMarker2,tubeMarker2,minScaleTubeMarker2,maxScaleTubeMarker2,threshMarker2,threshMarker2Fix, minAreaMarker2,false,true);
			selectImage(idMaskMarker2);
			rename("maskMarker2");

			//Nuclei and spot detection
			countNuc = segmentationNuclei2D(idSubMax,name); 
			if(countNuc>0){
				countCell = segmentationCell2D(name);
				roiManager("reset");
				countSpots = segmentationSpots2D(idSubMax,name,false);
			}else{
				print("No Nuclei detected");
				newImage("maskCell", "8-bit black", imgWidth, imgHeight, 1);
				idMaskCell = getImageID();
				run("Properties...", " unit="+micron+" pixel_width="+pixelSize+" pixel_height="+pixelSize);
				newImage("maskSpots", "8-bit black", imgWidth, imgHeight, 1);
				idMaskSpots = getImageID();
				run("Properties...", " unit="+micron+" pixel_width="+pixelSize+" pixel_height="+pixelSize);
			}

			//Summarise results
			readout = analyzeRegions(name);
			if(readout){
				summarizeResults(name);
			}
			analyzeMasks(idSubMax,idMaskMarker1,name,chMarker1);
			analyzeMasks(idSubMax,idMaskMarker2,name,chMarker2);

			//Visualisation
			selectImage(idSubMax);
			if(File.exists(dirOutput+name+"_CH"+chNuc+"_ROI_Cell.zip")){
				roiManager("Open",dirOutput+name+"_CH"+chNuc+"_ROI_Cell.zip");
				countCell=roiManager("count");
				roiManager("Set Color", "yellow");
				roiManager("Show All without labels");
			}
			if(File.exists(dirOutput+name+"_CH"+chNuc+"_ROI_Nuc.zip")){
				roiManager("Open",dirOutput+name+"_CH"+chNuc+"_ROI_Nuc.zip");
				countNuc=roiManager("count")-countCell;
				for(i=0; i<countNuc; i++){
					roiManager("Select", countCell+i);
					roiManager("Set Color", "cyan");
				}
				roiManager("Set Color", "red");
				roiManager("Show All without labels");
			}
			if(File.exists(dirOutput+name+"_CH"+chSpot+"_ROI.zip")){
				roiManager("Open",dirOutput+name+"_CH"+chSpot+"_ROI.zip");
				roiManager("Deselect");
				countSpot=roiManager("count")-countNuc-countCell;
				for(i=0; i<countSpot; i++){
					roiManager("Select", countNuc+countCell+i);
					roiManager("Set Color", "magenta");
				}
				roiManager("Show All without labels");
			}
			if(File.exists(dirOutput+name+"_CH"+chMarker1+"_ROI.zip")){
				roiManager("Open",dirOutput+name+"_CH"+chMarker1+"_ROI.zip");
				currentCount=roiManager("count");
				roiManager("Select", (currentCount-1));
				roiManager("Set Color", "green");
				roiManager("Show All without labels");
			}
			if(File.exists(dirOutput+name+"_CH"+chMarker2+"_ROI.zip")){
				roiManager("Open",dirOutput+name+"_CH"+chMarker2+"_ROI.zip");
				currentCount=roiManager("count");
				roiManager("Select", (currentCount-1));
				roiManager("Set Color", "red");
				roiManager("Show All without labels");
			}
			run("From ROI Manager");
			selectImage(idMaskMarker2); close();
			selectImage(idMaskMarker1); close();
			selectImage(idMaskNuclei); close();
			selectImage(idMaskSpots); close();
		}else{
			print("Standard deviation in image to low to detect nuclei");
		}
		it=it+1;
	}
	print((getTime()-start)/1000,"sec");
	print("Analysis Done");
	setBatchMode("exit and display");
	run("Tile");
	run("Synchronize Windows");
}

macro "Batch Analysis Action Tool - C888 T5f16#"{
	erase(1);
	run("ROI Manager...");
	setBatchMode(true);
	
	//Get Directory
	dirInput 	= getDirectory("Choose a Source Directory With Raw Images");
	dirMax 		= dirInput+"Max"+File.separator;
	dirSubMax 	= dirInput+"SubMax"+File.separator;
	dirOutput 	= dirInput+"Output"+File.separator;
	logPath 	= dirOutput+"Log.txt";

	if(!File.exists(dirMax)){
		print("No Max Projections Found. Run 'SplitAction' Tool");
	}
	if(!File.exists(dirSubMax)){
		print("No SubMax Projections Found. Run 'SplitAction' Tool");
	}
	if(!File.exists(dirOutput)){
		File.makeDirectory(dirOutput);
	}

	//Scan files
	list = getFileList(dirInput);
	prefixes = scanFiles();
	fields = prefixes.length;
	setup();
	start = getTime();
	for(i=0;i<fields;i++){
		prefix = prefixes[i];
		print(i+1,"/",fields,":",prefix);
		
		//Marker Detection
		path=dirMax+"Max_"+prefix+".tif";
		open(path);
		idMax=getImageID();

		//Image properties
		getPixelSize(unit, pixelWidth, pixelHeight);
		if(unit!=micron){
			run("Properties...", " unit="+micron+" pixel_width="+pixelSize+" pixel_height="+pixelSize);
		}else{
			pixelSize = pixelWidth;
		}

		//Intensity measurements
		selectImage(idMax);
		run("Select All");
		run("Set Measurements...", "mean standard min redirect=None decimal=2");
		run("Clear Results");
		for(c=1; c<=nChannels;c++){
			selectImage(idMax);
			Stack.setChannel(c);
			run("Measure");
		}
		saveAs("Measurements",dirOutput+prefix+"_ChannelInt.txt");
		run("Clear Results");

		//Marker detection
		idMaskMarker1 = segmentationMask2D (idMax,prefix,chMarker1,gausMarker1,tubeMarker1,minScaleTubeMarker1, maxScaleTubeMarker1,threshMarker1,threshMarker1Fix, minAreaMarker1,true,true);
		selectImage(idMaskMarker1);
		rename("maskMarker1");
		idMaskMarker2 = segmentationMask2D (idMax,prefix,chMarker2,gausMarker2,tubeMarker2,minScaleTubeMarker2,maxScaleTubeMarker2,threshMarker2,threshMarker2Fix, minAreaMarker2,false,true);
		selectImage(idMaskMarker2);
		rename("maskMarker2");

		//Analyze masks
		analyzeMasks(idMax,idMaskMarker1,prefix,chMarker1);
		analyzeMasks(idMax,idMaskMarker2,prefix,chMarker2);

		//Close images
		selectImage(idMaskMarker2); close();
		selectImage(idMaskMarker1); close();
		selectImage(idMax);close();

		//Analyse substacks
		it=1;
		while(File.exists(dirSubMax+"SubMax_"+prefix+"_"+it+".tif")){
			name=prefix+"_"+it;
			print("--Analysis Substack: "+it);
			path=dirSubMax+"SubMax_"+name+".tif";
			open(path);
			idSubMax=getImageID();

			//Image Properties
			getPixelSize(unit, pixelWidth, pixelHeight);
			if(unit!=micron){
				run("Properties...", " unit="+micron+" pixel_width="+pixelSize+" pixel_height="+pixelSize);
			}else{
				pixelSize = pixelWidth;
			}

			//Run if standard deviation of intensities > 2
			getStatistics(area, mean, min, max, std, histogram);
			if(std>2){
				//Marker detection
				idMaskMarker1 = segmentationMask2D (idSubMax,name,chMarker1,gausMarker1,tubeMarker1,minScaleTubeMarker1, maxScaleTubeMarker1,threshMarker1,threshMarker1Fix, minAreaMarker1,false,true);
				selectImage(idMaskMarker1);
				rename("maskMarker1");
				idMaskMarker2 = segmentationMask2D (idSubMax,name,chMarker2,gausMarker2,tubeMarker2,minScaleTubeMarker2,maxScaleTubeMarker2,threshMarker2,threshMarker2Fix, minAreaMarker2,false,true);
				selectImage(idMaskMarker2);
				rename("maskMarker2");

				//Nucleus and spot detection
				countNuc = segmentationNuclei2D(idSubMax,name); 
				if(countNuc>0){
					countCell = segmentationCell2D(name);
					roiManager("reset");
					countSpots = segmentationSpots2D(idSubMax,name,false);
				}else{
					print("No Nuclei detected");
					newImage("maskCell", "8-bit black", imgWidth, imgHeight, 1);
					idMaskCell = getImageID();
					run("Properties...", " unit="+micron+" pixel_width="+pixelSize+" pixel_height="+pixelSize);
					newImage("maskSpots", "8-bit black", imgWidth, imgHeight, 1);
					idMaskSpots = getImageID();
				}

				//Summarise results
				readout = analyzeRegions(name);
				if(readout){
					summarizeResults(name);
				}
				analyzeMasks(idSubMax,idMaskMarker1,name,chMarker1);
				analyzeMasks(idSubMax,idMaskMarker2,name,chMarker2);
				
				//Close Images
				selectImage(idMaskMarker2); close();
				selectImage(idMaskMarker1); close();
				selectImage(idMaskNuclei); close();
				selectImage(idMaskSpots); close();
			}else{
				print("Standard deviation in image to low to detect nuclei");
			}
			selectImage(idSubMax); close();
			it=it+1;
			erase(0);
		}
		erase(0);
	}
	print((getTime()-start)/1000,"sec");
	print("Analysis Done");
	if(isOpen("Log")){
		selectWindow("Log");
		saveAs("txt",dirOutput+"Log.txt");
	}
	setBatchMode("exit and display");
}

macro "Verification Nuclei and Spot Stack Action Tool - C888 T1f16V Taf07N Tff07S"{
	erase(1);
	setBatchMode(true);
	dirInput = getDirectory("Choose a Source Directory With Raw Images");
	list = getFileList(dirInput);
	
	dirMax = dirInput+"Max"+File.separator;
	dirSubMax = dirInput+"SubMax"+File.separator;
	dirOutput = dirInput+"Output"+File.separator;
	
	if(!File.exists(dirOutput) | !File.exists(dirOutput) |!File.exists(dirOutput)  ){
		print("No Output-, Max- or SubMax- Directory found");
	}else{
		logPath = dirOutput+"Log.txt";
		prefixes = scanFiles();
		n=prefixes.length;
		it=0;
		for (i = 0; i < n; i=i+100) {
			if(i+99>n){
				max=n-(it*100);
			}else{
				max=100;
				it=it+1;
			}
			prefixesSub=newArray(prefixes[i]);
			for (k = 1; k < max; k++) {
				prefixesSub=Array.concat(prefixesSub,prefixes[i+k]); 
			}
			createOverlayNucleiSpots(prefixesSub);
			setBatchMode("exit and display");
			run("Tile");
			run("Channels Tool... ");
			Stack.setDisplayMode("composite");
			Stack.setActiveChannels("100111");
			
			waitForUser("Next 100 images?");
			setBatchMode(true);
			run("Close All");
			run("Collect Garbage");		
		}
	}
}

macro "Verification Marker Stack Action Tool - C888 T1f16V Taf07M "{
	erase(1);
	setBatchMode(true);
	dirInput = getDirectory("Choose a Source Directory With Raw Images");
	list = getFileList(dirInput);
	dirOutput = dirInput+"Output"+File.separator;
	dirMax = dirInput+"Max"+File.separator;
	dirSubMax = dirInput+"SubMax"+File.separator;
	dirOutput = dirInput+"Output"+File.separator;
	if(!File.exists(dirOutput) | !File.exists(dirOutput) |!File.exists(dirOutput)  ){
		print("No Output-, Max- or SubMax- Directory found");
	}else{
		logPath = dirOutput+"Log.txt";
		prefixes = scanFiles();
		createOverlayMarkerStack(prefixes);
	}
	setBatchMode("exit and display");
	run("Tile");
	run("Channels Tool... ");
	Stack.setDisplayMode("composite");
	Stack.setActiveChannels("011011");
}

macro "Verification Marker SubStack Action Tool - C888 T1f16V Taf07M Tff07S"{
	erase(1);
	setBatchMode(true);
	dirInput = getDirectory("Choose a Source Directory With Raw Images");
	list = getFileList(dirInput);
	
	dirMax = dirInput+"Max"+File.separator;
	dirSubMax = dirInput+"SubMax"+File.separator;
	dirOutput = dirInput+"Output"+File.separator;
	
	if(!File.exists(dirOutput) | !File.exists(dirOutput) |!File.exists(dirOutput)  ){
		print("No Output-, Max- or SubMax- Directory found");
	}else{
		logPath = dirOutput+"Log.txt";
		prefixes = scanFiles();
		n=prefixes.length;
		it=0;
		for (i = 0; i < n; i=i+100) {
			if(i+99>n){
				max=n-(it*100);
			}else{
				max=100;
				it=it+1;
			}
			prefixesSub=newArray(prefixes[i]);
			for (k = 1; k < max; k++) {
				prefixesSub=Array.concat(prefixesSub,prefixes[i+k]); 
			}
			createOverlayMarkerSubStack(prefixesSub);
			setBatchMode("exit and display");
			run("Tile");
			run("Channels Tool... ");
			Stack.setDisplayMode("composite");
			Stack.setActiveChannels("011011");
			
			waitForUser("Next 100 images?");
			setBatchMode(true);
			run("Close All");
			run("Collect Garbage");		
		}
	}
}

macro "Toggle Overlay Action Tool - Caaa O11ee"{
	toggleOverlay();
}

macro "[t] Toggle Overlay"{
	toggleOverlay();
}

// ----- FUNCTIONS ----- //
function setup(){
	//erase(1);
	setOptions();
	Dialog.createNonBlocking("Huntington 2020: General settings");
	Dialog.setInsets(0,0,0);
	Dialog.addMessage("--------------------------------------------------   General Parameters  --------------------------------------------------", 14, "#ff0000");
	Dialog.setInsets(0,0,0);
	Dialog.addChoice("Image Type", filetypes, suffix);
	Dialog.addNumber("Pixel Size", pixelSize, 3, 5, micron);
	Dialog.addNumber("Number of Channels", nChannels, 0, 5, " ");
	Dialog.setInsets(0,0,0);	
	Dialog.addMessage("Channels:\n",12,"#ff0000");
	Dialog.setInsets(0,0,0);
	Dialog.addNumber("Nuclear Channel", chNuc, 0, 4, "");
	Dialog.addToSameRow();
	Dialog.addNumber("2B4 Spot Channel", chSpot, 0, 4, "");
	Dialog.addToSameRow();
	Dialog.addNumber("Marker1 Channel ", chMarker1, 0, 4, "");
	Dialog.addToSameRow();
	Dialog.addNumber("Marker2 Channel", chMarker2, 0, 4, "");
	Dialog.setInsets(0,0,0);	
	Dialog.addMessage("Background subtraction:\n",12,"#ff0000");
	Dialog.setInsets(0,100,0);
	Dialog.addCheckbox("Bg subtraction", bg);
	Dialog.addToSameRow();
	Dialog.addNumber("Radius filter", bgRadius, 2, 5, "px");
	Dialog.setInsets(0,0,0);
	Dialog.addMessage("--------------------------------------------------   Nuclei Segmentation  --------------------------------------------------", 14, "#ff0000");
	Dialog.setInsets(0,0,0);	
	Dialog.addMessage("PreProcessing:\n",12,"#ff0000");
	Dialog.setInsets(0,100,0);
	Dialog.addCheckbox("CLAHE (Local Contrast)", claheNuc);
	Dialog.addToSameRow();
	Dialog.addChoice("Filter",filters,filterNuc);
	Dialog.addToSameRow();
	Dialog.addNumber("Filter radius", filterNucScale, 2, 4, "");
	Dialog.setInsets(0,0,0);	
	Dialog.addMessage("Stardist:\n",12,"#ff0000");
	Dialog.setInsets(0,0,0);
	Dialog.addNumber("Probability", probNuc, 2, 4, "");
	Dialog.addToSameRow();
	Dialog.addNumber("Overlap", overlapNuc, 2, 4, "");
	Dialog.setInsets(0,0,0);	
	Dialog.addMessage("Nuclei filter:\n",12,"#ff0000");
	Dialog.setInsets(0,0,0);
	Dialog.addNumber("Min Area ", minAreaNuc, 2, 5, micron+"2");
	Dialog.addToSameRow();
	Dialog.addNumber("Max Area ", maxAreaNuc, 2, 5, micron+"2");
	Dialog.addToSameRow();
	Dialog.addNumber("Min Circ. ", minCircNuc, 2, 5, "");
	Dialog.setInsets(0,0,0);	
	Dialog.addMessage("Cell detection:\n",12,"#ff0000");
	Dialog.setInsets(0,0,0);
	Dialog.addNumber("Dilation", itCellMicron, 2, 5, micron+"2");
	Dialog.setInsets(0,0,0);
	Dialog.addMessage("--------------------------------------------------   Spot Segmentation  --------------------------------------------------", 14, "#ff0000");
	Dialog.setInsets(0,0,0);	
	Dialog.addMessage("Spot enhancement:\n",12,"#ff0000");
	Dialog.setInsets(0,100,0);
	Dialog.addCheckbox("Multi-scale detection", multiScaleSpot);
	Dialog.addToSameRow();
	Dialog.addNumber("Min Scale laplace", minScaleSpot, 2, 4, "");
	Dialog.addToSameRow();
	Dialog.addNumber("Max Scale laplace", maxScaleSpot, 2, 4, "");
	Dialog.setInsets(0,100,0);
	Dialog.addCheckbox("Max finding", maxFindingSpot);
	Dialog.setInsets(0,0,0);	
	Dialog.addMessage("Spot detection:\n",12,"#ff0000");
	Dialog.setInsets(0,0,0);
	Dialog.addNumber("Fixed Threshold", threshSpot, 2, 4, "");
	Dialog.setInsets(0,0,0);	
	Dialog.addMessage("Spot filter:\n",12,"#ff0000");
	Dialog.setInsets(0,0,0);
	Dialog.addNumber("Min Area ", minAreaSpot, 2, 5, micron+"2");
	Dialog.addToSameRow();
	Dialog.addNumber("Max Area ", maxAreaSpot, 2, 5, micron+"2");
	Dialog.addToSameRow();
	Dialog.addNumber("Min Circ. ", minCircSpot, 2, 5, "");
	Dialog.setInsets(0,0,0);	
	Dialog.addMessage("Exclude vessel structures:\n",12,"#ff0000");
	Dialog.setInsets(0,100,0);
	Dialog.addCheckbox("Exclude vessel", excludeVesselStructures);
	Dialog.addToSameRow();
	Dialog.addNumber("Gaussian Blur Radius", gausExclude, 2, 4, "");
	Dialog.setInsets(0,100,0);
	Dialog.addCheckbox("Tube enhancement", tubeExclude);
	Dialog.addToSameRow();
	Dialog.addNumber("Min Scale", minScaleExclude, 2, 4, "");
	Dialog.addToSameRow();
	Dialog.addNumber("Max Scale", maxScaleExclude, 2, 4, "");
	Dialog.addChoice("Threshold Algortihm", threshMethods, threshExclude);
	Dialog.addToSameRow();
	Dialog.addNumber("Fixed Threshold", threshExcludeFix, 2, 4, "");
	Dialog.addNumber("Minimum Area ", minAreaExclude, 2, 5, micron+"2");
	Dialog.addToSameRow();
	Dialog.addNumber("Minimum Length ", minVesselLengthExclude, 2, 5, micron);
	Dialog.setInsets(0,0,0);
	Dialog.show();

	print("-------Settings-------");
	suffix			= Dialog.getChoice();	
	pixelSize		= Dialog.getNumber(); 		print("Pixel size:",pixelSize);
	nChannels 		= Dialog.getNumber();		print("Channels:",nChannels);
	chNuc 			= Dialog.getNumber();		print("Channel Nuclei:", chNuc);
	chSpot 			= Dialog.getNumber();		print("Channel 2B4 Spot:", chSpot);
	chMarker1 		= Dialog.getNumber();		print("Channel Marker 1:", chMarker1);
	chMarker2		= Dialog.getNumber();		print("Channel Marker 2:", chMarker2);
	bg				= Dialog.getCheckbox();		print("Background subtraction:", bg);
	bgRadius		= Dialog.getNumber();		print("Radius background subtraction:", bgRadius);

	claheNuc		= Dialog.getCheckbox();		print("CLAHE nculei:",claheNuc);
	filterNuc		= Dialog.getChoice();		print("Filter nuclei:",filterNuc);
	filterNucScale	= Dialog.getNumber();		print("Filter radius nuclei:",filterNucScale);
	probNuc			= Dialog.getNumber();		print("Stardist Probability Threshold:",probNuc);
	overlapNuc		= Dialog.getNumber();		print("Stardist Overlap Threshold:",overlapNuc);
	minAreaNuc		= Dialog.getNumber();		print("Min area nuclei:",minAreaNuc);
	maxAreaNuc		= Dialog.getNumber();		print("Max area nuclei:",maxAreaNuc);
	minCircNuc		= Dialog.getNumber();		print("Max area nuclei:",minCircNuc);
	itCellMicron	= Dialog.getNumber();		print("Dilation Cell Detection:", itCellMicron);

	multiScaleSpot	= Dialog.getCheckbox();		print("Multiscale spot detection:",multiScaleSpot);
	minScaleSpot 	= Dialog.getNumber();		print("Min Laplace radius spots:", minScaleSpot);
	maxScaleSpot 	= Dialog.getNumber();		print("Max Laplace radius spots:", maxScaleSpot);
	maxFindingSpot	= Dialog.getCheckbox();		print("Max finding spot detection:", maxFindingSpot);
		
	threshSpot		= Dialog.getNumber();		print("Fixed threshold spots:", threshSpot);
	minAreaSpot		= Dialog.getNumber();		print("Min area spots:",minAreaSpot);
	maxAreaSpot		= Dialog.getNumber();		print("Max area spots:",maxAreaSpot);
	minCircSpot		= Dialog.getNumber();		print("Min circ spots:",minCircSpot);

	excludeVesselStructures = Dialog.getCheckbox(); 	print("Exclude vessel structures:",excludeVesselStructures);
	gausExclude				= Dialog.getNumber();		print("Blur radius Exclude:",gausExclude);
	tubeExclude				= Dialog.getCheckbox();		print("Edge enhancement Exclude:",tubeExclude);
	minScaleExclude			= Dialog.getNumber();		print("Min Scale Tube enhancement Exclude:",minScaleExclude);
	maxScaleExclude			= Dialog.getNumber();		print("Max Scale Tube enhancement Exclude:",maxScaleExclude);
	threshExclude			= Dialog.getChoice();		print("Auto Threshold Exclude:",threshExclude);
	threshExcludeFix		= Dialog.getNumber();		print("Fixed Threshold Exclude:",threshExcludeFix);
	minAreaExclude			= Dialog.getNumber();		print("Min area Exclude:",minAreaExclude);
	minVesselLengthExclude	= Dialog.getNumber();		print("Min vessel length Exclude:", minVesselLengthExclude);

	Dialog.createNonBlocking("Huntington 2020: General settings");
	Dialog.addMessage("--------------------------------------------------   Marker 1 Segmentation  --------------------------------------------------", 14, "#ff0000");
	Dialog.setInsets(0,0,0);	
	Dialog.addMessage("Preprocessing:\n",12,"#ff0000");
	Dialog.setInsets(0,0,0);
	Dialog.addNumber("Gaussian Blur Radius", gausMarker1, 2, 4, "");
	Dialog.setInsets(0,0,0);	
	Dialog.addMessage("Tube enhancement:\n",12,"#ff0000");
	Dialog.setInsets(0,100,0);
	Dialog.addCheckbox("Tube enhancement", tubeMarker1);
	Dialog.addToSameRow();
	Dialog.addNumber("Min Scale", minScaleTubeMarker1, 2, 4, "");
	Dialog.addToSameRow();
	Dialog.addNumber("Max Scale", maxScaleTubeMarker1, 2, 4, "");
	Dialog.setInsets(0,0,0);	
	Dialog.addMessage("Segmentation:\n",12,"#ff0000");
	Dialog.setInsets(0,0,0);
	Dialog.addChoice("Threshold Algortihm", threshMethods, threshMarker1);
	Dialog.addToSameRow();
	Dialog.addNumber("Fixed Threshold", threshMarker1Fix, 2, 4, "");
	Dialog.setInsets(0,0,0);	
	Dialog.addMessage("Object filter:\n",12,"#ff0000");
	Dialog.setInsets(0,0,0);
	Dialog.addNumber("Minimum Area ", minAreaMarker1, 2, 5, micron+"2");
	Dialog.setInsets(0,0,0);
	Dialog.addMessage("--------------------------------------------------   Marker 2 Segmentation  --------------------------------------------------", 14, "#ff0000");
	Dialog.setInsets(0,0,0);	
	Dialog.addMessage("Preprocessing:\n",12,"#ff0000");
	Dialog.setInsets(0,0,0);
	Dialog.addNumber("Gaussian Blur Radius", gausMarker2, 2, 4, "");
	Dialog.setInsets(0,0,0);	
	Dialog.addMessage("Tube enhancement:\n",12,"#ff0000");
	Dialog.setInsets(0,100,0);
	Dialog.addCheckbox("Tube enhancement", tubeMarker2);
	Dialog.addToSameRow();
	Dialog.addNumber("Min Scale", minScaleTubeMarker2, 2, 4, "");
	Dialog.addToSameRow();
	Dialog.addNumber("Max Scale", maxScaleTubeMarker2, 2, 4, "");
	Dialog.setInsets(0,0,0);	
	Dialog.addMessage("Segmentation:\n",12,"#ff0000");
	Dialog.setInsets(0,0,0);
	Dialog.addChoice("Threshold Algortihm", threshMethods, threshMarker2);
	Dialog.addToSameRow();
	Dialog.addNumber("Fixed Threshold", threshMarker2Fix, 2, 4, "");
	Dialog.setInsets(0,0,0);	
	Dialog.addMessage("Object Filter:\n",12,"#ff0000");
	Dialog.setInsets(0,0,0);
	Dialog.addNumber("Minimum Area ", minAreaMarker2, 2, 5, micron+"2");
	Dialog.setInsets(0,0,0);
	Dialog.show();

	gausMarker1		= Dialog.getNumber();	print("Blur radius lectin/GFAP:",gausMarker1);
	tubeMarker1		= Dialog.getCheckbox();		print("Edge enhancement lectin/GFAP:",tubeMarker1);
	minScaleTubeMarker1= Dialog.getNumber();		print("Min Scale Tube enhancement lectin/GFAP:",minScaleTubeMarker1);
	maxScaleTubeMarker1= Dialog.getNumber();		print("Max Scale Tube enhancement lectin/GFAP:",maxScaleTubeMarker1);
	threshMarker1	= Dialog.getChoice();		print("Auto Threshold lectin/GFAP:",threshMarker1);
	threshMarker1Fix	= Dialog.getNumber();		print("Fixed Threshold lectin/GFAP:",threshMarker1Fix);
	minAreaMarker1	= Dialog.getNumber();		print("Min area lectin/GFAP:",minAreaMarker1);
	
	gausMarker2		= Dialog.getNumber();		print("Blur radius Marker2:",gausMarker2);
	tubeMarker2		= Dialog.getCheckbox();		print("Edge enhancement Marker2:",tubeMarker2);
	minScaleTubeMarker2= Dialog.getNumber();		print("Scale Tube enhancement Marker2:",minScaleTubeMarker2);
	maxScaleTubeMarker2= Dialog.getNumber();		print("Scale Tube enhancement Marker2:",maxScaleTubeMarker2);
	threshMarker2	= Dialog.getChoice();		print("Auto Threshold Marker2:",threshMarker2);
	threshMarker2Fix	= Dialog.getNumber();		print("Fixed Threshold Marker2:",threshMarker2Fix);
	minAreaMarker2	= Dialog.getNumber();		print("Min area Marker2:",minAreaMarker2);
	print("--------------------");
}

function setOptions(){
	run("Options...", "iterations=1 count=1");
	run("Colors...", "foreground=white background=black selection=yellow");
	run("Overlay Options...", "stroke=red width=1 fill=none");
	setBackgroundColor(0, 0, 0);
	setForegroundColor(255,255,255);
}

function scanFiles(){
	prefixes = newArray(0);
	for(i=0;i<list.length;i++)
	{
		path = dirInput+list[i];
		if(endsWith(path,suffix) && indexOf(path,"flat")<0)
		{
			print(path);
			prefixes = Array.concat(prefixes,substring(list[i],0,lastIndexOf(list[i],suffix)));			
		}
	}
	return prefixes;
}

function segmentationNuclei2D (id,name){
	selectImage(id);
	if(Stack.isHyperstack){
		run("Duplicate...", "title=copy duplicate channels="+chNuc);	
	}
	else{
		setSlice(chNuc);
		run("Duplicate...","title=chNuc");
	}
	idChannel=getImageID();
	selectImage(idChannel);
	if(bg){
		run("Subtract Background...", "rolling="+bgRadius);
	}
	if(claheNuc){
		run("Enhance Local Contrast (CLAHE)", "blocksize=100 histogram=256 maximum=3 mask=*None* fast_(less_accurate)");
	}
	if(filterNuc=="Gaussian"){
		run("Gaussian Blur...", "sigma="+filterNucScale);
	}else if(filterNuc=="Median"){
		run("Median...", "radius="+filterNucScale);
	}
	selectImage(idChannel);
	run("Command From Macro", "command=[de.csbdresden.stardist.StarDist2D], "
	+"args=['input':'chNuc', 'modelChoice':'Versatile (fluorescent nuclei)',"
	+"'normalizeInput':'true', 'percentileBottom':'1.0', 'percentileTop':'99.8',"
	+"'probThresh':'"+probNuc+"', 'nmsThresh':'"+overlapNuc+"', 'outputType':'ROI Manager', 'nTiles':'1', "
	+"'excludeBoundary':'0', 'roiPosition':'Automatic', 'verbose':'false', "
	+"'showCsbdeepProgress':'false', 'showProbAndDist':'false'], process=[false]");
	selectImage(idChannel); 
	//close;		
	run("Set Measurements...", "area shape redirect=None decimal=2");
	roiManager("Measure");
	newImage("maskNuc", "8-bit black", imgWidth, imgHeight, 1);
	run("Properties...", " unit="+micron+" pixel_width="+pixelSize+" pixel_height="+pixelSize);
	idMaskNuclei = getImageID;
	selectImage(idMaskNuclei);
	countRoi = roiManager("count");
	for(r = 0; r < countRoi; r++)
	{
		if(getResult("Area", r)>minAreaNuc && getResult("Area", r)<maxAreaNuc && getResult("Circ.", r)>minCircNuc){
			roiManager("select",r);
			run("Enlarge...", "enlarge=1");
			run("Clear");
			run("Enlarge...", "enlarge=-1");
			run("Fill");
		}
	}		
	roiManager("Deselect");
	roiManager("reset");
	setThreshold(1,255);
	run("Convert to Mask");
	run("Analyze Particles...", "size=1-Infinity circularity=0-1.00 show=Nothing exclude add");
	countNuc = roiManager("count");
	for(i=0;i<countNuc;i++){
		roiManager("select",i);
		if(i<9){
			roiManager("Rename","000"+i+1);
		}else if(i<99){
			roiManager("Rename","00"+i+1);	
		}else if(i<999){
			roiManager("Rename","0"+i+1);
		}else roiManager("Rename",i+1);
	}
	if(countNuc>0){
		roiManager("Save",dirOutput+name+"_CH"+chNuc+"_ROI_Nuc.zip");
		print("# Nuclei detected: "+countNuc);
	}else{
		if(File.exists(dirOutput+name+"_CH"+chNuc+"_ROI_Nuc.zip")){
			File.delete(dirOutput+name+"_CH"+chNuc+"_ROI_Nuc.zip");
		}
		if(File.exists(dirOutput+name+"_CH"+chNuc+"_Results_Nuc.txt")){
			File.delete(dirOutput+name+"_CH"+chNuc+"_Results_Nuc.txt");
		}
	}
	
	selectImage(idChannel); close();

	selectImage(idMaskNuclei);
	setAutoThreshold("Default dark");
	setThreshold(2, 255);
	setOption("BlackBackground", false);
	run("Convert to Mask");
	run("Remove Overlay");
	return countNuc;
}


function segmentationCell2D(name){
	selectImage(idMaskNuclei); 
	run("Select None");
	
	// generate voronoi regions from all detected nuclei (including edges)
	run("Duplicate...","title=voronoi");
	idVoronoi = getImageID;
	selectImage(idVoronoi);
	run("Voronoi");
	setThreshold(1, 255);
	run("Convert to Mask");
	run("Invert");
	
	// generate dilated nuclei (using more accurate EDM mapping (by x iterations) requires the biovioxxel package) - now just using the enlarge function
	selectImage(idMaskNuclei);
	run("Duplicate...","title=dilate");
	idDupMaskNuclei = getImageID;
	selectImage(idDupMaskNuclei); 
	run("Create Selection"); 
	it=itCellMicron/pixelSize;
	run("Enlarge...", "enlarge="+it+" pixel");
	roiManager("Add");
	run("Select All");
	run("Fill");
	sel = roiManager("count")-1;
	roiManager("select", sel);
	run("Clear", "slice");
	roiManager("Delete");
	run("Select None");
	run("Invert LUT");
	imageCalculator("AND create", "voronoi","dilate");
	selectImage(idDupMaskNuclei); close; 
	selectImage(idVoronoi); close;
	selectWindow("Result of voronoi");
	if(is("Inverting LUT")){
		run("Invert LUT");
	}
	run("Invert");
	idVoronoi = getImageID;

	// keep only the non-excluded nuclei (pos nuclei)
	newImage("posnuclei", "16-bit Black", imgWidth, imgHeight, 1); 
	idPosNuc = getImageID;
	selectImage(idPosNuc); 
	rmc = roiManager("count"); //print(rmc);
	for(i=0;i<rmc;i++)
	{
		roiManager("select",i);
		run("Set...", "value="+i+1);
	}
	run("Select None");
	if(!exclude_nuclei){
		roiManager("reset"); 
		rmc=0;
	}
	selectImage(idVoronoi);
	run("Analyze Particles...", "size=0-Infinity circularity=0.00-1.00 show=Nothing add");
	rmcb = roiManager("count");  //print(rmcb);
	selectImage(idPosNuc);
	for(i=rmcb-1;i>=rmc;i--){
		roiManager("select",i); 
		getRawStatistics(np,mean,min,max);
		if(max==0){
			roiManager("delete"); // no nuc retained
		} 				
		else if(max<10)roiManager("Rename","000"+max);	// assigned to correct nucl
		else if(max<100)roiManager("Rename","00"+max);	
		else if(max<1000)roiManager("Rename","0"+max);	
		else roiManager("Rename",max);
	}
	rmcc = roiManager("count"); //print(rmcc);
	if(rmcc>rmc){
		roiManager("Sort"); 
		// select expanded regions without nuclei
		index = 0;
		if(exclude_nuclei){
			for(i=0;i<=rmcc-2;i+=2){
				couple = newArray(i,i+1);
				roiManager("select",couple); 
				index = getInfo("roi.name");	
				roiManager("XOR"); 
				roiManager("Add");
				roiManager("select",roiManager("count")-1);
				roiManager("Rename",index);
			}
			roiManager("select",Array.getSequence(rmcc));
			roiManager("Delete"); 
		}
		run("Select None");
		countCell = roiManager("count");
	}else{
		countCell = 0;
	}
	
	if(countCell>0){
		roiManager("Save",dirOutput+name+"_CH"+chNuc+"_ROI_Cell.zip");
		print("# Cells detected: "+countCell);
	}else{
		if(File.exists(dirOutput+name+"_CH"+chNuc+"_ROI_Cell.zip")){
			File.delete(dirOutput+name+"_CH"+chNuc+"_ROI_Cell.zip");
		}
		if(File.exists(dirOutput+name+"_CH"+chNuc+"_Results_Cell.txt")){
			File.delete(dirOutput+name+"_CH"+chNuc+"_Results_Cell.txt");
		}
	}
	selectImage(idVoronoi); close;
	selectImage(idPosNuc); close;
	return countCell;
}


function segmentationSpots2D (id,name, booleanDebug){
	selectImage(id);
	roiManager("reset");
	if(Stack.isHyperstack){
		run("Duplicate...", "title=copy duplicate channels="+chSpot);	
	}
	else{
		setSlice(chSpot);
		run("Duplicate...","title=copy ");
	}
	idChannel = getImageID();
	selectImage(idChannel);
	if(bg){
		run("Subtract Background...", "rolling="+bgRadius);
	}

	if(excludeVesselStructures){
		idMaskExclude=segmentationMask2D(id,name,chSpot,gausExclude,tubeExclude,minScaleExclude,maxScaleExclude,threshExclude,threshExcludeFix,minAreaExclude, false, false);
		run("Duplicate...","title=Skeleton ");
		idSkeleton=getImageID();
		run("Skeletonize");

		selectImage(idMaskExclude);
		run("Analyze Particles...", "size=0-Infinity circularity=0.00-1.00 add show=Nothing");
		
		selectImage(idSkeleton);
		run("Analyze Skeleton (2D/3D)", "prune=none");
		selectWindow("Tagged skeleton");
		rename("Tagged");
		idTag = getImageID;
		run("Set Measurements...", "integrated redirect=None decimal=4");
		setThreshold(127,127);
		run("Convert to Mask");
		roiManager("Measure");


		selectImage(idMaskExclude);
		run("Invert");
		run("Invert LUT");
		for(i = 0; i < roiManager("count"); i++){
			length=getResult("IntDen",i)/255/pixelSize; 
			if(length < minVesselLengthExclude){
				selectImage(idMaskExclude);
				roiManager("select", i);
				setForegroundColor(255, 255, 255);
				run("Fill", "slice");
			}
		}
		
		selectImage(idMaskExclude);
		run("Select None");
		run("Remove Overlay");
		rename("Exclude");
		roiManager("reset");
		selectImage(idSkeleton); close();
		selectImage(idTag); close();
	}

	//Laplace
	if(multiScaleSpot){
		selectImage(idChannel);
		title=getTitle();
		e=minScaleSpot;
		while(e<=maxScaleSpot){
			selectImage(idChannel);
			run("FeatureJ Laplacian", "compute smoothing="+e);
			selectWindow(title+" Laplacian");
			run("Multiply...","value="+e*e); // Normalise
			rename("scale "+e); 
			eid = getImageID;
			if(e>minScaleSpot){
				selectImage(eid);
				run("Select All");
				run("Copy");
				close;
				selectWindow("scale "+minScaleSpot);
				run("Add Slice");
				run("Paste");
			}
			e++;
		}
		selectWindow("scale "+minScaleSpot);
		nlid = getImageID;
		selectImage(nlid);
		
		run("Z Project...", "start=1 projection=[Sum Slices]");

		rename("Laplace");
		idLaplace = getImageID;
		selectImage(nlid); close;
		
	}else{
		selectImage(idChannel);
		run("FeatureJ Laplacian", "compute smoothing="+minScaleSpot);
		rename("Laplace");
		idLaplace = getImageID;
	}
	
	//Binary Mask Spots
	selectImage(idLaplace);
	run("Duplicate...","LaplaceDup");
	setThreshold(-2147483648, -threshSpot);
	setOption("BlackBackground", false);
	run("Convert to Mask");
	rename("maskLaplace");
	idLaplaceBinary = getImageID();

	//Max finding
	if(maxFindingSpot){
		selectImage(idLaplace);
		run("Find Maxima...", "prominence=1 light output=[Segmented Particles]");
		idRegions=getImageID();
		rename("Regions");
		imageCalculator("AND","maskLaplace", "Regions");
	}

	//Exclude Vessels
	if(excludeVesselStructures){
		imageCalculator("AND","maskLaplace", "Exclude");
	}

	//Save Spots
	selectImage(idLaplaceBinary);
	run("Analyze Particles...", "size="+minAreaSpot+"-"+maxAreaSpot+" circularity="+minCircSpot+"-1.00 show=Masks display exclude clear include add");
	
	idMaskSpots=getImageID();
	selectImage(idMaskSpots);
	countSpots = roiManager("count"); 
	if(countSpots>0){
		roiManager("Save",dirOutput+name+"_CH"+chSpot+"_ROI.zip");
		print("# Spots detected: "+countSpots);
	}else{
		if(File.exists(dirOutput+name+"_CH"+chSpot+"_ROI.zip")){
			File.delete(dirOutput+name+"_CH"+chSpot+"_ROI.zip");
		}
		if(File.exists(dirOutput+name+"_CH"+chSpot+"_Results.txt")){
			File.delete(dirOutput+name+"_CH"+chSpot+"_Results.txt");
		}
	}

	selectImage(idChannel); close();
	selectImage(idLaplaceBinary); close();
	if(maxFindingSpot){
		selectImage(idRegions); close();
	}
	selectImage(idMaskSpots);
	if(!booleanDebug){
		selectImage(idLaplace); close();
		selectImage(idMaskExclude); close();
	}
	selectImage(idMaskSpots);
	setAutoThreshold("Default dark");
	setThreshold(2, 255);
	setOption("BlackBackground", false);
	run("Convert to Mask");
	rename("maskSpots");
	return countSpots;
}

function segmentationMask2D (id,name,ch,gaus,tube,minScaleTube,maxScaleTube,threshMet,threshFix,minArea, booleanSkeleton, saveRoiList){
	selectImage(id);
	roiManager("reset");
	if(Stack.isHyperstack){
		run("Duplicate...", "title=copy duplicate channels="+ch);	
	}
	else{
		setSlice(ch);
		run("Duplicate...","title=copy");
	}
	idChannel = getImageID();
	selectImage(idChannel);
	if(bg){
		run("Subtract Background...", "rolling="+bgRadius);
	}
	run("Gaussian Blur...", "sigma="+gaus);

	if(tube){
		e=0;
		scale=minScaleTube;
		selectImage(idChannel);
		title=getTitle();
		e=minScaleTube;
		while(e<=maxScaleTube){
			selectImage(idChannel);
			run("Tubeness", "sigma="+e+" use");
			selectWindow("tubeness of "+title);
			rename("scale "+e); 
			eid = getImageID;
			if(e>minScaleTube){
				selectImage(eid);
				run("Select All");
				run("Copy");
				close;
				selectWindow("scale "+minScaleTube);
				run("Add Slice");
				run("Paste");
			}
			e++;
		}
		selectImage(idChannel); close();
		selectWindow("scale "+minScaleTube);
		idTempStack = getImageID;
		selectImage(idTempStack);
		Stack.getDimensions(width, height, channels, slices, frames);

		if(slices>1){
			run("Z Project...", "start=1 projection=[Sum Slices]");
		}else{
			selectImage(idTempStack);
			run("Duplicate...","title=Dup");
		}
		
		idChannel = getImageID;
		selectImage(idTempStack); close;
	}
	
	selectImage(idChannel);
	if(threshMet=="Fixed"){
		setAutoThreshold("Default dark");
		getThreshold(minThr,maxThr); 
		setThreshold(threshFix,maxThr);
		run("Convert to Mask");
	}else {
		 setAutoThreshold(threshMet+" dark");
		 run("Convert to Mask");
	}
	rename("Thresh");

	run("Analyze Particles...", "size="+minArea+"- infinity circularity=0-1.00 show=Masks");
	
	idMask=getImageID();
	rename("mask");
	setAutoThreshold("Default dark");
	setThreshold(2, 255);
	setOption("BlackBackground", false);
	run("Convert to Mask");
	run("Select None");

	if(saveRoiList){
		getStatistics(area, mean, min, max, std, histogram);
		if(max>0){
			run("Create Selection");
			roiManager("Add");
			roiManager("Save",dirOutput+name+"_CH"+ch+"_ROI.zip");
			run("Select None");	
		}else{
			if(File.exists(dirOutput+name+"_CH"+ch+"_ROI.zip")){
				File.delete(dirOutput+name+"_CH"+ch+"_ROI.zip");
			}
			if(File.exists(dirOutput+name+"_CH"+ch+"_Results.txt")){
				File.delete(dirOutput+name+"_CH"+ch+"_Results.txt");
			}
		}
	}

	selectImage(idChannel); close();

	//Skeleton
	if(booleanSkeleton){
		roiManager("reset");
		selectImage(idMask);

		run("Duplicate...","title=Skeleton");
		idSkeleton=getImageID();
		selectImage(idSkeleton);
		
		run("Skeletonize (2D/3D)");
		
		selectImage(idMask);
		run("Duplicate...","title=DistanceMap");
		idDistance=getImageID();
		selectImage(idDistance);
		run("Distance Map");

		selectImage(idSkeleton);
		run("Analyze Skeleton (2D/3D)", "prune=none prune_0 display");
		selectWindow("Tagged skeleton"); close();
		selectWindow("Skeleton-labeled-skeletons");
		idSkeletonResult=getImageID();
		getStatistics(area, mean, min, max, std, histogram);
		for(i=1;i<=max;i++){
			selectImage(idSkeletonResult);
			run("Duplicate...","title=Temp");
			idTemp=getImageID();
			setThreshold((i-0.5), (i+0.5));
			setOption("BlackBackground", true);
			run("Convert to Mask");
			run("Create Selection");
			roiManager("Add");
			selectImage(idTemp); close();
		}

		countSkeleton=roiManager("count");
		if(countSkeleton>0){
			IJ.renameResults("Results","Temp");
			run("Set Measurements...", "area mean min redirect=None decimal=4");
			newImage("Matrix", "32-bit Black",4, countSkeleton, 1);
			idMatrix=getImageID();
			for(i=0;i<countSkeleton;i++){
				selectImage(idDistance);
				roiManager("select", i);
				roiManager("measure");
				selectImage(idMatrix);
				setPixel(0, i, (getResult("Area", 0)/pixelSize));
				setPixel(1, i, (getResult("Mean", 0)*pixelSize));
				setPixel(2, i, (getResult("Min", 0)*pixelSize));
				setPixel(3, i, (getResult("Max", 0)*pixelSize));
				run("Clear Results");
				
			}
			IJ.renameResults("Temp","Results");
			for(i=0;i<countSkeleton;i++){
				selectImage(idMatrix);
				value=getPixel(0, i);
				setResult("Total length", i, value);
				value=getPixel(1, i);
				setResult("Mean width", i, value);
				value=getPixel(2, i);
				setResult("Min width", i, value);
				value=getPixel(3, i);
				setResult("Max width", i, value);
			}
			updateResults();

			if(saveRoiList){
				roiManager("Save",dirOutput+name+"_CH"+ch+"_Skeleton.zip");
				selectWindow("Results");
				saveAs("Results",dirOutput+name+"_CH"+ch+"_Skeleton.txt");
				run("Close");
			}
			selectImage(idMatrix); close();
		}else{
			if(File.exists(dirOutput+name+"_CH"+ch+"_Skeleton.zip")){
				File.delete(dirOutput+name+"_CH"+ch+"_Skeleton.zip");
			}
			if(File.exists(dirOutput+name+"_CH"+ch+"_Skeleton.txt")){
				File.delete(dirOutput+name+"_CH"+ch+"_Skeleton.txt");
			}
		}
		selectImage(idSkeleton); close();
		selectImage(idDistance); close();
		selectImage(idSkeletonResult); close();
		roiManager("reset");
	}
	return idMask;
}

function analyzeRegions(name){
	erase(0); 
	mask = 0;
	readout = 1;
	//run("Subtract Background...", "rolling=100");
	if(File.exists(dirOutput+name+"_CH"+chNuc+"_ROI_Cell.zip")){
		run("Set Measurements...", "  area mean median standard min redirect=None decimal=4");
		roiManager("Open",dirOutput+name+"_CH"+chNuc+"_ROI_Cell.zip");
		countCell = roiManager("count");
		selectImage(idSubMax);
		for(c=1;c<=nChannels;c++){
			setSlice(c);
			roiManager("deselect");
			roiManager("Measure");
		}
		run("Set Measurements...", "  area mean median standard min limit redirect=None decimal=4");
		selectImage(idMaskMarker1);
		roiManager("deselect");
		roiManager("Measure");
		selectImage(idMaskMarker2);
		roiManager("deselect");
		roiManager("Measure");
		
		sortResults(); // organize results per channel
		if(!isOpen(mask))
		{
			newImage("Mask", "32-bit Black",imgWidth, imgHeight, 1); 	//	reference image for spot assignments
			mask = getImageID; 
		}
		selectImage(mask);
		for(j=0;j<countCell;j++)
		{
			roiManager("select",j);
			index = getInfo("roi.name");
			run("Set...", "value="+0-index);							//	negative values for cytoplasm, positive for nuclei
		}	
		saveAs("Measurements",dirOutput+name+"_CH"+chNuc+"_Results_Cell.txt");
		erase(0);
	}	
	
	//	analyze nuclear rois
	if(File.exists(dirOutput+name+"_CH"+chNuc+"_ROI_Nuc.zip")){
		run("Set Measurements...", "  area centroid perimeter shape feret's mean median standard min redirect=None decimal=4");
		roiManager("Open",dirOutput+name+"_CH"+chNuc+"_ROI_Nuc.zip");
		countNuc = roiManager("count");
		selectImage(idSubMax);
		for(c=1;c<=nChannels;c++)
		{
			setSlice(c);
			roiManager("deselect");
			roiManager("Measure");
		}
		run("Set Measurements...", "  area centroid perimeter shape feret's mean median standard min limit redirect=None decimal=4");
		selectImage(idMaskMarker1);
		roiManager("deselect");
		roiManager("Measure");
		selectImage(idMaskMarker2);
		roiManager("deselect");
		roiManager("Measure");

		sortResults();

		//Create nuclear reference image
		if(!isOpen(mask)){
			newImage("Mask", "32-bit Black",imgWidth, imgHeight, 1); 
			mask = getImageID;
		}
		selectImage(mask);
		for(j=0;j<countNuc;j++){
			roiManager("select",j);
			index = getInfo("roi.name");
			run("Set...", "value="+index);			//	negative values for cytoplasm, positive for nuclei
			setResult("Cell",j,index);
		}	
		run("Select None");

		//Save Results and clear
		updateResults;
		saveAs("Measurements",dirOutput+name+"_CH"+chNuc+"_Results_Nuc.txt");
		erase(0);
		selectImage(idSubMax);
		run("Remove Overlay");
		selectWindow("Results"); 
		run("Close");
	}	
	//	analyze spot rois
	if(File.exists(dirOutput+name+"_CH"+chSpot+"_ROI.zip")){	
		selectImage(mask); ms = nSlices;
		run("Set Measurements...", "  area mean median standard min redirect=None decimal=4");
		roiManager("Open",dirOutput+name+"_CH"+chSpot+"_ROI.zip");
		countSpots = roiManager("count");
		selectImage(idSubMax);
		for(c=1;c<=nChannels;c++){
			setSlice(c);
			roiManager("deselect");
			roiManager("Measure");
		}
		run("Set Measurements...", "  area mean median standard min limit redirect=None decimal=4");
		selectImage(idMaskMarker1);
		roiManager("deselect");
		roiManager("Measure");
		selectImage(idMaskMarker2);
		roiManager("deselect");
		roiManager("Measure");
		sortResults();
		IJ.renameResults("Results","Temp");

		
		// determine the location of the spots (cell vs. nucleus)
		selectImage(mask); setSlice(1);
		roiManager("deselect");
		roiManager("Measure");
		nindices = newArray(countSpots);
		cindices = newArray(countSpots);	
		for(j=0;j<countSpots;j++)
		{
			min = getResult("Min",j);
			max = getResult("Max",j);
			if(max>0){
				nindices[j] = max; 
				cindices[j] = max;
			}
			else if(min<0){
				nindices[j] = 0; cindices[j] = -min;
			}
		}	
		run("Clear Results");
		IJ.renameResults("Temp","Results");
		for(j=0;j<countSpots;j++)
		{
			setResult("Nucleus",j,nindices[j]);
			setResult("Cell",j,cindices[j]);
		}
		updateResults;
		saveAs("Measurements",dirOutput+name+"_CH"+chSpot+"_Results.txt");
		erase(0);
		selectImage(idSubMax);
		run("Remove Overlay");
		selectWindow("Results"); 
		run("Close");
	}
	if(isOpen(mask)){
		selectImage(mask); close;
	}else{
		readout = 0;
	}
	return readout;
}

function analyzeMasks(id,idMask,name,ch){
	erase(0); 
	readout = 1;
	selectImage(idMask);
	getStatistics(area, mean, min, max, std, histogram);
	if(max>0){
		run("Set Measurements...", "  area mean median standard min redirect=None decimal=4");
		selectImage(idMask);
		run("Create Selection");
		roiManager("add");
		selectImage(id);
		for(c=1;c<=nChannels;c++)
		{
			setSlice(c);
			roiManager("deselect");
			roiManager("Measure");
		}
		run("Set Measurements...", "  area mean median standard min limit redirect=None decimal=4");
		selectImage(idMaskMarker1);
		roiManager("deselect");
		roiManager("Measure");
		selectImage(idMaskMarker2);
		roiManager("deselect");
		roiManager("Measure");
		sortResults();
		updateResults;

		//	append summarized spot results
		if(File.exists(dirOutput+name+"_CH"+chSpot+"_Results.txt")){
			IJ.renameResults("Results","Temp");
			run("Results... ", "open=["+dirOutput+name+"_CH"+chSpot+"_Results.txt]");
			snr = nResults;
			areaMask = newArray(snr);
			for(j=0;j<snr;j++){
				areaMask[j] = getResult("Area_MM"+ch,j);
			}	
			resultLabels = getResultLabels();
			matrix = results2matrix(resultLabels);
			selectWindow("Results"); run("Close");
			IJ.renameResults("Temp","Results");
			
			for(s=0;s<resultLabels.length;s++){
				if(resultLabels[s] != "Nucleus" && resultLabels[s] != "Cell"){
					value=0;
					number=0;
					for(r=0;r<snr;r++){
						selectImage(matrix);
						p = getPixel(s,r);
						if(areaMask[r]>0){
							value = value + p;  
							number= number + 1;	
						}
					}
					setResult("Spot_SC"+chSpot+"_Nr",0,number);
					setResult("Spot_SC"+chSpot+"_"+resultLabels[s]+"_Sum",0,value);              
					setResult("Spot_SC"+chSpot+"_"+resultLabels[s]+"_Mean",0,value/number);
				}
			}
			selectImage(matrix); close;
			updateResults();
		}

		saveAs("Measurements",dirOutput+name+"_CH"+ch+"_Results.txt");
		erase(0);
		selectImage(idMask); run("Remove Overlay");
		selectImage(idMaskMarker1); run("Remove Overlay");run("Select None");
		selectImage(idMaskMarker2); run("Remove Overlay"); run("Select None");		
		selectWindow("Results"); 
		run("Close");
	}else{
		print("Empty Mask");
	}
	return readout;
}

function summarizeResults(name){
	
	// 	open nuclei results
	run("Results... ", "open=["+dirOutput+name+"_CH"+chNuc+"_Results_Nuc.txt]");
	nnr 			= nResults;
	indices			= newArray(nnr);
	resultLabels 	= getResultLabels();
	matrix 			= results2matrix(resultLabels);
	selectWindow("Results"); 
	run("Close");
	for(r=0;r<nnr;r++)
	{
		for(s=0;s<resultLabels.length;s++)
		{
			selectImage(matrix);
			p = getPixel(s,r);
			if(resultLabels[s]!="Cell" && resultLabels[s]!="X_MC1" && resultLabels[s]!="Y_MC1")setResult("Nucl_SC"+chNuc+"_"+resultLabels[s],r,p); // Label all nuclear measured parameters except for the cell or X and Y indices with a "Nucl" prefix
			else if(resultLabels[s]=="X_MC1")setResult("X",r,p);  //exception for X,Y coordinates for ease of tracing-back
			else if(resultLabels[s]=="Y_MC1")setResult("Y",r,p); 
			else setResult(resultLabels[s],r,p);
		}
	}
	updateResults;
	selectImage(matrix); close;
	
	//	append cellular results
	if(File.exists(dirOutput+name+"_CH"+chNuc+"_Results_Cell.txt"))
	{	
		for(r=0;r<nnr;r++){
			indices[r]=getResult("Cell",r)-1;
		}
		//Array.print(indices);
		IJ.renameResults("Results","Temp");
		run("Results... ", "open=["+dirOutput+name+"_CH"+chNuc+"_Results_Cell.txt]");
		resultLabels = getResultLabels();
		matrix = results2matrix(resultLabels);
		selectWindow("Results"); run("Close");
		IJ.renameResults("Temp","Results");
		for(r=0;r<nnr;r++)
		{
			for(s=0;s<resultLabels.length;s++)
			{
				selectImage(matrix);
				p = getPixel(s,indices[r]);
				setResult("Cell_SC"+chNuc+"_"+resultLabels[s],r,p); // Label all cytoplasmic measured parameters with a "Cell" prefix
			}
		}
		updateResults;
		selectImage(matrix); close;
	}
	//	append summarized spot results
	if(File.exists(dirOutput+name+"_CH"+chSpot+"_Results.txt"))
	{
		IJ.renameResults("Results","Temp");
		run("Results... ", "open=["+dirOutput+name+"_CH"+chSpot+"_Results.txt]");
		snr 			= nResults;
		nindices 		= newArray(snr);
		cindices 		= newArray(snr);
		for(j=0;j<snr;j++)
		{
			nindices[j] = getResult("Nucleus",j)-1;
			cindices[j] = getResult("Cell",j)-1;
		}	
		resultLabels = getResultLabels();
		matrix = results2matrix(resultLabels);
		selectWindow("Results"); run("Close");
		IJ.renameResults("Temp","Results");
		for(s=0;s<resultLabels.length;s++){
			if(resultLabels[s] != "Nucleus" && resultLabels[s] != "Cell"){
				nvalues 	= newArray(nnr);
				cvalues 	= newArray(nnr);
				nnumber 	= newArray(nnr);
				cnumber 	= newArray(nnr);
				for(r=0;r<snr;r++)
				{
					selectImage(matrix);
					p = getPixel(s,r);
					if(nindices[r]>=0)
					{
						nvalues[nindices[r]] += p;  
						nnumber[nindices[r]] += 1;	
					}
					if(exclude_nuclei && nindices[r]<0 && cindices[r]>=0)  // excl. nuclei
					{
						cvalues[cindices[r]] += p;  
						cnumber[cindices[r]] += 1;	
					}
					else if(!exclude_nuclei && cindices[r]>=0)			// incl. nuclei
					{
						cvalues[cindices[r]] += p;	
						cnumber[cindices[r]] += 1;	
					}	
				}
				for(r=0;r<nnr;r++)
				{
					setResult("Spot_SC"+chSpot+"_NrPerNuc",r,nnumber[r]);
					setResult("Spot_SC"+chSpot+"_"+resultLabels[s]+"_SumPerNuc",r,nvalues[r]);              
					setResult("Spot_SC"+chSpot+"_"+resultLabels[s]+"_MeanPerNuc",r,nvalues[r]/nnumber[r]);
					setResult("Spot_SC"+chSpot+"_NrPerCell",r,cnumber[indices[r]]);
					setResult("Spot_SC"+chSpot+"_"+resultLabels[s]+"_SumPerCell",r,cvalues[indices[r]]);
					setResult("Spot_SC"+chSpot+"_"+resultLabels[s]+"_MeanPerCell",r,cvalues[indices[r]]/cnumber[indices[r]]);
				}
			}
		}
		selectImage(matrix); close;
		updateResults();
	}
	selectWindow("Results"); 
	saveAs("Measurements",dirOutput+name+"_Summary.txt");
}

function sortResults(){
	resultLabels = getResultLabels();
	matrix = results2matrix(resultLabels);
	matrix2results(matrix,resultLabels);
}

function getResultLabels(){
	//Extract Column names from results table
	selectWindow("Results");
	ls 				= split(getInfo(),'\n');
	rr 				= split(ls[0],'\t'); 
	nparams 		= rr.length-1;			
	resultLabels 	= newArray(nparams);
	for(j=1;j<=nparams;j++){
		resultLabels[j-1]=rr[j];
	}
	return resultLabels;
}

function results2matrix(resultLabels){
	h = nResults;
	w = resultLabels.length;
	newImage("Matrix", "32-bit Black",w, h, 1);
	matrix = getImageID;
	for(j=0;j<w;j++)
	{
		for(r=0;r<h;r++)
		{
			v = getResult(resultLabels[j],r);
			selectImage(matrix);
			setPixel(j,r,v);
		}
	}
	run("Clear Results");
	return matrix;
}

function matrix2results(matrix,resultLabels){
	selectImage(matrix);
	w = getWidth;
	h = getHeight;
	n=nChannels+2; //Channels + 2 masks
	for(c=0;c<n;c++){
		start = (c/n)*h;
		end = ((c+1)/n)*h;
		for(k=0;k<w;k++){
			for(j=start;j<end;j++){
				selectImage(matrix);
				p = getPixel(k,j);
				if(c<nChannels){
					setResult(resultLabels[k]+"_MC"+c+1,j-start,p); // MC for measurement channel
				}
				if(c==nChannels){
					setResult(resultLabels[k]+"_MM"+chMarker1,j-start,p);
				}
				if(c==(nChannels+1)){
					setResult(resultLabels[k]+"_MM"+chMarker2,j-start,p);
				}
			}
		}
	}
	selectImage(matrix); close;
	updateResults;
}

function splitRegions(){
	erase(1);
	Dialog.create("Split Fields...");
	Dialog.addChoice("Import format",filetypes,".mvd2");
	Dialog.addChoice("Export format",filetypes,suffix);
	Dialog.addNumber("Z-Range of substacks", 5, 0, 3, "");
	Dialog.addNumber("Z-Increment between substacks", 2, 0, 3, "");
	Dialog.show;
	ext			= Dialog.getChoice;
	suffix 		= Dialog.getChoice;
	zRange 		= Dialog.getNumber();
	zIncrement 	= Dialog.getNumber();
	
	dirInput = getDirectory("Choose input directory (master or subfolder)");
	dirDest = getDirectory("Choose output directory");

	list1 = getFileList(dirInput);
	if(endsWith(list1[1], File.separator)){
		print("Subfolders found:");
		for(i=0;i<list1.length;i++){
			print("Folder: "+list1[i]);
		}
	}
	
	for(i=0;i<list1.length;i++){
		print("Read: ");
		if(endsWith(list1[i], File.separator)){
			print("Folder: "+list1[i]);
			list2 = getFileList(dirInput+list1[i]);
			for(j=0;j<list2.length;j++){
				path=dirInput+list1[i]+list2[j];
				if(endsWith(path,ext)){		
					run("Bio-Formats Importer", "open=["+path+"] color_mode=Default open_all_series view=Hyperstack ");
					n=nImages;
					while(nImages>0){
						print("Nr Images to save:"+nImages);
						selectImage(nImages);
						getDimensions(width, height, channels, slices, frames);
						name = getTitle;
						name=replace(name, "/", "_");

						//Extract region
						startIndex=indexOf(name,"_");
						stopIndex=indexOf(name,"_",startIndex+1);
						region=substring(name,startIndex+1,stopIndex);
						dirRegion=dirDest+region+File.separator;
						dirSubMax = dirRegion+"SubMax"+File.separator;
						dirMax = dirRegion+"Max"+File.separator;
						if(!File.exists(dirRegion)){
							File.makeDirectory(dirRegion);
							File.makeDirectory(dirSubMax);
							File.makeDirectory(dirMax);
						}
						
						cid = getImageID;
						selectImage(cid);
						saveAs(suffix,dirRegion+name+suffix);	

						//ZProjection
						selectImage(cid);
						run("Z Project...", " projection=[Max Intensity]");
						maxId=getImageID();
						selectImage(maxId);
						saveAs(suffix,dirMax+"Max_"+name);
						selectImage(maxId);close();
			
						//ZProjection Substacks
						selectImage(cid);
						getDimensions(width, height, channels, slices, frames);
						it=Math.floor(slices/(zIncrement+zRange));
						for(k=1;k<=it;k++){
							selectImage(cid);
							lowerZ=1+(k*zIncrement)+(k-1)*(zRange);
							upperZ=k*(zIncrement+zRange);
							run("Duplicate...", "duplicate slices="+lowerZ+"-"+upperZ);
							idSub=getImageID();
							run("Z Project...", "projection=[Max Intensity]");
							idMax=getImageID();
							index=k;
							saveAs(suffix,dirSubMax+"SubMax_"+name+"_"+index);	
							selectImage(idMax); close();
							selectImage(idSub); close();	
						}
						selectImage(cid); close();
					}
				}
			}
		}else{
			path = dirInput+list1[i];
			if(endsWith(path,ext)){	
				print(path);	
				run("Bio-Formats Importer", "open=["+path+"] color_mode=Default open_all_series view=Hyperstack ");
				while(nImages>0){
						print("Nr Images to save:"+nImages);
						selectImage(nImages);
						getDimensions(width, height, channels, slices, frames);
						name = getTitle;
						name=replace(name, "/", "_");

						//Extract region
						startIndex=indexOf(name,"_");
						stopIndex=indexOf(name,"_",startIndex+1);
						region=substring(name,startIndex+1,stopIndex);
						dirRegion=dirDest+region+File.separator;
						dirSubMax = dirRegion+"SubMax"+File.separator;
						dirMax = dirRegion+"Max"+File.separator;
						if(!File.exists(dirRegion)){
							File.makeDirectory(dirRegion);
							File.makeDirectory(dirSubMax);
							File.makeDirectory(dirMax);
						}
						
						cid = getImageID;
						selectImage(cid);
						saveAs(suffix,dirRegion+name+suffix);	

						//ZProjection
						selectImage(cid);
						run("Z Project...", " projection=[Max Intensity]");
						maxId=getImageID();
						selectImage(maxId);
						saveAs(suffix,dirMax+"Max_"+name);
						selectImage(maxId);close();
			
						//ZProjection Substacks
						selectImage(cid);
						getDimensions(width, height, channels, slices, frames);
						it=Math.floor(slices/(zIncrement+zRange));
						for(k=1;k<=it;k++){
							selectImage(cid);
							lowerZ=1+(k*zIncrement)+(k-1)*(zRange);
							upperZ=k*(zIncrement+zRange);
							run("Duplicate...", "duplicate slices="+lowerZ+"-"+upperZ);
							idSub=getImageID();
							run("Z Project...", "projection=[Max Intensity]");
							idMax=getImageID();
							index=k;
							saveAs(suffix,dirSubMax+"SubMax_"+name+"_"+index);	
							selectImage(idMax); close();
							selectImage(idSub); close();	
						}	
						selectImage(cid); close();
				}
			}
		}	
	}
	print("Done");
}

function createOverlayNucleiSpots(prefixes)
{
	setForegroundColor(25, 25, 25);
	fields = prefixes.length;
	index=1;
	for(i=0;i<fields;i++){
		prefix = prefixes[i];
		it=1;
		while(File.exists(dirSubMax+"SubMax_"+prefix+"_"+it+".tif")){
			name=prefix+"_"+it;
			print("Frame: "+ index + " - Image: "+name);
			path=dirSubMax+"SubMax_"+name+".tif";
			open(path);
			id = getImageID;
			Stack.getDimensions(w,h,channels,slices,frames); 
			if(!Stack.isHyperStack && channels == 1){
				channels = slices;
				run("Stack to Hyperstack...", "order=xyczt(default) channels="+channels+" slices=1 frames=1 display=Composite");
			}
			id = getImageID;
			setSlice(nSlices);
			if(chNuc>0){
				selectImage(id);
				setSlice(nSlices);
				run("Add Slice","add=channel");
				if(File.exists(dirOutput+name+"_CH"+chNuc+"_ROI_Nuc.zip")){	
					selectImage(id);
					setSlice(nSlices);
					roiManager("Open",dirOutput+name+"_CH"+chNuc+"_ROI_Nuc.zip");
					roiManager("deselect");
					roiManager("Fill");
					roiManager("reset");
				}
			}
			if(chSpot>0){
				selectImage(id);
				setSlice(nSlices);
				run("Add Slice","add=channel");
				if(File.exists(dirOutput+name+"_CH"+chSpot+"_ROI.zip")){	
					selectImage(id);
					setSlice(nSlices);
					roiManager("Open",dirOutput+name+"_CH"+chSpot+"_ROI.zip");
					roiManager("deselect");
					roiManager("Fill");
					roiManager("reset");
				}
			}
			it=it+1;
			index=index+1;
		}
	}
	run("Concatenate...", "all_open title=[Concatenated Stacks]");
	Stack.getDimensions(w,h,newchannels,slices,frames);
	for(c=1;c<=nChannels;c++){
		Stack.setChannel(c);
		Stack.setFrame(round(frames/2));
		resetMinAndMax;
	}
	range = pow(2,bitDepth);
	for(c=nChannels+1;c<=newchannels;c++){
		Stack.setChannel(c);
		setMinAndMax(0,range/2);
	}
	run("Make Composite");
}

function createOverlayMarkerStack(prefixes)
{
	setForegroundColor(25, 25, 25);
	fields = prefixes.length;

	//Max
	for(i=0;i<fields;i++){
		prefix = prefixes[i];
		file = prefix+suffix;
		print("Frame: " + (i+1) + " - Image: " + prefix);
		path = dirMax+"Max_"+prefix+".tif";
		run("Bio-Formats Importer", "open=["+path+"] color_mode=Default open_files view=Hyperstack stack_order=XYCZT");
		id = getImageID;
		Stack.getDimensions(w,h,channels,slices,frames); 
		if(!Stack.isHyperStack && channels == 1)
		{
			channels = slices;
			run("Stack to Hyperstack...", "order=xyczt(default) channels="+channels+" slices=1 frames=1 display=Composite");
		}
		id = getImageID;
		if(chMarker1>0){
			selectImage(id);
			setSlice(nSlices);
			run("Add Slice","add=channel");
			if(File.exists(dirOutput+prefix+"_CH"+chMarker1+"_ROI.zip")){	
				selectImage(id);
				setSlice(nSlices);
				roiManager("Open",dirOutput+prefix+"_CH"+chMarker1+"_ROI.zip");
				roiManager("deselect");
				roiManager("Fill");
				roiManager("reset");
			}
		}
		if(chMarker2>0){
			selectImage(id);
			setSlice(nSlices);
			run("Add Slice","add=channel");
			if(File.exists(dirOutput+prefix+"_CH"+chMarker2+"_ROI.zip")){	
				selectImage(id);
				setSlice(nSlices);
				roiManager("Open",dirOutput+prefix+"_CH"+chMarker2+"_ROI.zip");
				roiManager("deselect");
				roiManager("Fill");
				roiManager("reset");
			}
		}
	}
	
	run("Concatenate...", "all_open title=[Concatenated Stacks]");
	Stack.getDimensions(w,h,newchannels,slices,frames);
	for(c=1;c<=nChannels;c++){
		Stack.setChannel(c);
		Stack.setFrame(round(frames/2));
		resetMinAndMax;
	}
	range = pow(2,bitDepth);
	for(c=nChannels+1;c<=newchannels;c++){
		Stack.setChannel(c);
		setMinAndMax(0,range/2);
	}
	run("Make Composite");
}

function createOverlayMarkerSubStack(prefixes)
{
	setForegroundColor(25, 25, 25);
	fields = prefixes.length;
	index=1;
	for(i=0;i<fields;i++){
		prefix = prefixes[i];
		it=1;
		while(File.exists(dirSubMax+"SubMax_"+prefix+"_"+it+".tif")){
			name=prefix+"_"+it;
			print("Frame: " + index + " - Image: "+name);
			path=dirSubMax+"SubMax_"+name+".tif";
			open(path);
			id = getImageID;
			Stack.getDimensions(w,h,channels,slices,frames); 
			if(!Stack.isHyperStack && channels == 1){
				channels = slices;
				run("Stack to Hyperstack...", "order=xyczt(default) channels="+channels+" slices=1 frames=1 display=Composite");
			}
			id = getImageID;
			setSlice(nSlices);
			if(chMarker1>0){
				selectImage(id);
				setSlice(nSlices);
				run("Add Slice","add=channel");
				if(File.exists(dirOutput+name+"_CH"+chMarker1+"_ROI.zip")){	
					selectImage(id);
					setSlice(nSlices);
					roiManager("Open",dirOutput+name+"_CH"+chMarker1+"_ROI.zip");
					roiManager("deselect");
					roiManager("Fill");
					roiManager("reset");
				}
			}
			if(chMarker2>0){
				selectImage(id);
				setSlice(nSlices);
				run("Add Slice","add=channel");
				if(File.exists(dirOutput+name+"_CH"+chMarker2+"_ROI.zip")){	
					selectImage(id);
					setSlice(nSlices);
					roiManager("Open",dirOutput+name+"_CH"+chMarker2+"_ROI.zip");
					roiManager("deselect");
					roiManager("Fill");
					roiManager("reset");
				}
			}
			it=it+1;
			index=index+1;
		}
	}
	run("Concatenate...", "all_open title=[Concatenated Stacks]");
	Stack.getDimensions(w,h,newchannels,slices,frames);
	for(c=1;c<=nChannels;c++){
		Stack.setChannel(c);
		Stack.setFrame(round(frames/2));
		resetMinAndMax;
	}
	range = pow(2,bitDepth);
	for(c=nChannels+1;c<=newchannels;c++){
		Stack.setChannel(c);
		setMinAndMax(0,range/2);
	}
	run("Make Composite");
}

function toggleOverlay(){	
	if(Overlay.size == 0){
		run("From ROI Manager");
		roiManager("reset");
	}
	else{
		run("To ROI Manager");
		run("Remove Overlay"); 
	}
}

function erase(all){
	if(all){
		print("\\Clear");
		run("Close All");
	}
	run("Clear Results");
	roiManager("reset");
	run("Collect Garbage");
}