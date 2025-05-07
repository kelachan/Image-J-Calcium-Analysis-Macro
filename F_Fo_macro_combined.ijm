// delta F/F0 macro calculation for tiffs and czi files
// Requires template matching and N2V plugins for certain preprocessing steps
// Assumes z is time slice.


// Open Image to be quantified
path1 = File.openDialog("Select Image to quantify");
open(path1); 
dir1 = File.getParent(path1);
name1 = File.getName(path1);
print("Loaded Image: " + name1 + " from " + dir1);

// Ask if the user has a PI image
Dialog.create("PI Image Selection");
Dialog.addCheckbox("Do you have a PI image labeling dead cells?", false);
Dialog.show();
hasPI = Dialog.getCheckbox();

// If the user has a PI image, ask them to open it
if (hasPI) {
    path2 = File.openDialog("Select PI Image");
    open(path2);
    dir2 = File.getParent(path2);
    name2 = File.getName(path2);
    print("Loaded PI Image: " + name2 + " from " + dir2);
}

// Preprocessing Options Dialog
Dialog.create("Preprocessing Options");
Dialog.addCheckbox("Align slices in stack?", false);
Dialog.addCheckbox("Run N2V train + predict?", false);
Dialog.addCheckbox("Crop image?", false);
Dialog.show();
alignOption = Dialog.getCheckbox();
denoiseOption = Dialog.getCheckbox();
cropOption = Dialog.getCheckbox();


// Apply Align stacks (If selected)
if (alignOption) {
    selectWindow(name1);
    run("Align slices in stack...", "");
	}
    
// Apply Cropping (If selected)
if (cropOption) {
    waitForUser("Draw a rectangular ROI on the quantification image for cropping, then click OK.");
    roiManager("Add & draw");
    run("Crop");
    if (hasPI) { // Retains ROI for cropping on PI image
        selectWindow(name2);
	roiManager("Select", 0);
        run("Crop");
    }
     roiManager("Deselect");
     roiManager("Delete");
}

// Apply Noise2Void Denoising (If selected)
if (denoiseOption) {
    selectWindow(name1);
    run("N2V train + predict", "");
    
    if (hasPI) {
        selectWindow(name2);
   		run("N2V train + predict", "");
    }
}

// WEKA Segmentation for the cells
if (hasPI) {
    // Segment PI Image (Dead Cells)
    selectWindow(name2);
    run("Trainable Weka Segmentation");
    waitForUser("Load a classifier or create a new one for the PI image, then generate the probability map.");
    run("8-bit");
    run("Make Binary");
    run("Watershed");

    // Extract ROIs from PI Image
    run("Set Measurements...", "area mean centroid slice");
    run("Analyze Particles...", "show=Outlines display clear include add");
    roiPath2 = dir2 + File.separator + "PI_ROIs.zip";
    roiManager("Save", roiPath2);

    // Segment Original Image (Healthy Cells)
    selectWindow(name1);
    run("Z Project...", "projection=[Max Intensity]"); // Max intensity for WEKA on quantificaton image
	projectedFileName = "MAX_" + name1;
    run("Trainable Weka Segmentation");
    waitForUser("Load a classifier or create a new one for the quantification image, then generate the probability map.");
    run("8-bit");
    run("Make Binary");
    run("Watershed");

    // Extract ROIs from Original Image
    run("Set Measurements...", "area mean centroid slice");
    run("Analyze Particles...", "show=Outlines display clear include add");
    roiPath1 = dir1 + File.separator + "Quant_ROIs.zip";
    roiManager("Save", roiPath1);

	// Get user-defined minimum area for ROIs (default: 50 pixels)
	minArea = getNumber("Enter the minimum area for valid ROIs (Recommended: 50 pixels):", 50);
	print("Minimum ROI area set to: " + minArea);

    // Create masks from WEKA ROIs
	roiManager("Reset");
	roiManager("Open", roiPath1);
	roiManager("Select All");
	roiManager("Combine");
	run("Create Mask");
	rename("ROI_Mask_Alive");
	
	roiManager("Reset");
	roiManager("Open", roiPath2);
	roiManager("Select All");
	roiManager("Combine");
	run("Create Mask");
	rename("ROI_Mask_Dead");
	
    // Find overlap of PI Mask and Quant Mask and subtract from Quant Mask
	imageCalculator("AND create", "ROI_Mask_Alive", "ROI_Mask_Dead");
	rename("Overlapping_ROIs");
	imageCalculator("Subtract create", "ROI_Mask_Alive", "Overlapping_ROIs");
	rename("NonOverlapping_ROIs");
	
	// Extract remaining non-overlapping ROIs
	selectWindow("NonOverlapping_ROIs");
	setThreshold(1, 255); // Threshold for noise created during subtraction
	run("Convert to Mask");
	run("Analyze Particles...", "size=" + minArea + "-Infinity show=Outlines display clear include add");

    // Save the cleaned ROIs
    roiPathFinal = dir1 + File.separator + "Final_ROIs.zip";
    roiManager("Save", roiPathFinal);
    print("Saved final non-overlapping ROIs (Live Cells) at: " + roiPathFinal);

    // Delete temporary files and close extraneous windows
    File.delete(roiPath1);
    File.delete(roiPath2);
	close("ROI_Mask_Alive");
	close("ROI_Mask_Dead");
	close("Overlapping_ROIs");
	close("NonOverlapping_ROIs");
	close("Drawing of NonOverlapping_ROIs");
	close("Probability maps");
	close("Probability maps");
	close("Trainable Weka Segmentation v4.0.0");
	close("Trainable Weka Segmentation v4.0.0");
	close("Drawing of Probability maps");
	close("Drawing of Probability maps");

} else {
    // Standard WEKA + ROI workflow for images without PI
    run("Z Project...", "projection=[Max Intensity]");
	projectedFileName = "MAX_" + name1;
    run("Trainable Weka Segmentation");
    waitForUser("Load a pretrained classifier or create a new one, then generate the probability map.");
    run("8-bit");
    run("Make Binary");
    run("Watershed");
    
	// Get user-defined minimum area (default: 50 pixels)
	minArea = getNumber("Enter the minimum area for valid ROIs (Recommended: 50 pixels):", 50);
	print("Minimum ROI area set to: " + minArea);
    run("Set Measurements...", "area mean centroid slice");
	run("Analyze Particles...", "size=" + minArea + "-Infinity show=Outlines display clear include add");
    roiPathFinal = dir1 + File.separator + "Final_ROIs.zip";
    roiManager("Save", roiPathFinal);
    print("Saved ROIs at: " + roiPathFinal);
    
    // Close windows
    close("Probability maps");
    close("Trainable Weka Segmentation v4.0.0");
    close("Drawing of Probability maps");
}



// Measure mean gray value using the created ROIs
selectWindow(name1);
roiManager("Open", roiPathFinal); // Load the saved ROIs
roiManager("multi measure append");

// Define output path for the resulting CSV file
outputPath = dir1
+ "\\delta_FF0_results.csv";
print("Saving results to:", outputPath);
header = "Slice, Cell, X, Y, Mean, F/F0\n";
File.saveString(header, outputPath);

// Find dimensions of results table
numberOfRows = nResults;
print("Number of rows:", numberOfRows);
numberOfCols = 0; // Dynamically count columns
while (true) {
    colName = "Mean" + (numberOfCols + 1);
    if (!isNaN(getResult(colName, 0))) {
        numberOfCols += 3;
    } else {
        break;
    }
}
print("Number of columns:", numberOfCols);

// Calculate number of cells (ROIs measured) 
numCells = (numberOfCols) / 3;
print("Number of cells detected:", numCells);

// Ask user for baseline frames used to calculate F0 for each cell
baselineFrames = getNumber("Enter number of frames to use for calculating baseline F0:", 5);
print("Using first", baselineFrames, "frames to calculate F0");
baselineFo = newArray(numCells);
for (i = 0; i < numCells; i++) {
    baselineFo[i] = NaN;
}

// Calculate the average baseline F0 across the selected frames
for (cell = 1; cell <= numCells; cell++) {
    sumFo = 0;
    countFo = 0;  
    for (row = 0; row < baselineFrames; row++) {
        meanCol = "Mean" + cell;
        mean = getResult(meanCol, row);
        if (!isNaN(mean)) {
            sumFo += mean;
            countFo++;
        }
    }
    if (countFo > 0) {
        baselineFo[cell - 1] = sumFo / countFo;
        print("Baseline F0 for Cell", cell, ":", baselineFo[cell - 1]);
    } else {
        print("Warning: No valid F0 values found for Cell", cell);
        baselineFo[cell - 1] = NaN;
    }
}

// Create the calculation results table
Table.create("delta_FF0_results");
rowIndex = 0;
// delta F/F0 calculation, and storage of cell coordinates
for (row = 0; row < numberOfRows; row++) {
    slice = row + 1;
    for (cell = 1; cell <= numCells; cell++) {
        meanCol = "Mean" + cell;
        xCol = "X" + cell; 
        yCol = "Y" + cell;
        
        mean = getResult(meanCol, row);
        x = getResult(xCol, row);
        y = getResult(yCol, row);
        
        if (!isNaN(baselineFo[cell - 1])) {
            deltaFF = (mean - baselineFo[cell - 1]) / baselineFo[cell - 1];
        } else {
            deltaFF = NaN;
            print("Warning: Undefined baseline for Cell", cell);
        }
        Table.set("Slice", rowIndex, slice);
        Table.set("Cell", rowIndex, cell);
        Table.set("X", rowIndex, x);
        Table.set("Y", rowIndex, y);
        Table.set("Mean", rowIndex, mean);
        Table.set("F/F0", rowIndex, deltaFF);

        line = slice + "," + cell + "," + x + "," + y + "," + mean + "," + deltaFF + "\n";
        File.append(line, outputPath);

        rowIndex++;
    }
}

// Debugging check for data in the calculation table
if (rowIndex > 0) {
    Table.save(outputPath);
    print("Results table saved to:", outputPath);
} else {
    print("Error: No data was added to the table. Check for missing measurements.");
}

// Retrieve data from the created table for plotting
timePoints = Table.getColumn("Slice");
cells = Table.getColumn("Cell");
deltaFF0 = Table.getColumn("F/F0");

// Plotting
colors = newArray("red", "blue", "green", "magenta", "cyan", "orange", "yellow", "black"); // Color list cycled for graphing each cell

Plot.create("delta F/F0 Over Time", "Time (Slice)", "delta F/F0");

// Loop through each detected cell and plot its values
for (cell = 1; cell <= numCells; cell++) {
    xValues = newArray(numberOfRows);
    yValues = newArray(numberOfRows);
    index = 0;

    for (row = 0; row < rowIndex; row++) {
        if (cells[row] == cell) {
            xValues[index] = timePoints[row];
            yValues[index] = deltaFF0[row];
            index++;
        }
    }

    xValues = Array.slice(xValues, 0, index);
    yValues = Array.slice(yValues, 0, index);

    if (index > 0) {
        colorIndex = (cell - 1) % colors.length;
        Plot.setColor(colors[colorIndex]);
        Plot.add("line", xValues, yValues);
    }
}

Plot.show();

// Close extraneous windows
close(projectedFileName);
close("ROI Manager");
close("Results");

// Threshold loop, contingent on user acceptance of the graph
// Discards cells whose peak value is below the threshold
accepted = false;
while (!accepted) {
    // Ask the user for a threshold for filtering cells
    thresholdValue = getNumber("Enter a threshold for delta F/F0 (cells with peaks below this will be removed):", 0.2);
    print("Threshold set to:", thresholdValue);

    // Identify cells to keep
    cellsToKeep = newArray();
    tolerance = 0.01; // Set a small tolerance to detect peaks

    for (cell = 1; cell <= numCells; cell++) {
        cellData = newArray();
        
        for (row = 0; row < rowIndex; row++) {
            if (cells[row] == cell) {
                cellData = Array.concat(cellData, deltaFF0[row]);
            }
        }
        
        if (cellData.length > 0) {
            maxima = Array.findMaxima(cellData, tolerance);
            if (maxima.length > 0 && cellData[maxima[0]] >= thresholdValue) {
                cellsToKeep = Array.concat(cellsToKeep, cell);
            }
        }
    }

    print("Cells remaining after thresholding:", cellsToKeep.length);
    if (cellsToKeep.length == 0) {
        print("No cells meet the threshold criteria. Please enter a new threshold.");
        continue; // Restart loop to ask for a new threshold
    }

    graphTitle = "Filtered delta F/F0 Over Time (Threshold: " + thresholdValue + ")";
    if (isOpen(graphTitle)) { // Close the old graph before plotting again
        close(graphTitle);
    }

    // Replot the kept cells
    Plot.create(graphTitle, "Time (Slice)", "delta F/F0");

    legendLabels = "";
    
    for (i = 0; i < cellsToKeep.length; i++) {
        cell = cellsToKeep[i];
        xValues = newArray(numberOfRows);
        yValues = newArray(numberOfRows);
        index = 0;

        for (row = 0; row < rowIndex; row++) {
            if (cells[row] == cell) {
                xValues[index] = timePoints[row];
                yValues[index] = deltaFF0[row];
                index++;
            }
        }

        xValues = Array.slice(xValues, 0, index);
        yValues = Array.slice(yValues, 0, index);

        if (index > 0) {
            colorIndex = (cell - 1) % colors.length;
            Plot.setColor(colors[colorIndex]);
            Plot.add("line", xValues, yValues);

            // Add cell ID to the legend
            legendLabels = legendLabels + "Cell " + cell + "\n";
        }
    }

    // Display filtered plot
    Plot.setLegend(legendLabels, "top-right");
    Plot.show();

    // Ask the user if they accept the thresholded graph
    Dialog.createNonBlocking("Graph Confirmation");
    Dialog.addMessage("Do you accept this graph?\n(Threshold used: " + thresholdValue + ")");
    Dialog.addChoice("Choose an option:", newArray("Accept", "Try Again"), "Accept");
    Dialog.show();

    response = Dialog.getChoice();

    if (response == "Accept") {
        accepted = true;
        print("Graph accepted. Exiting.");
    } else {
        print("Try again. Asking for a new threshold.");
    }
}
