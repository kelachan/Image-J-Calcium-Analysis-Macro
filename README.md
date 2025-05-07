# Image-J-Calcium-Analysis-Macro
Perform Calcium Analysis of individual cells within ImageJ - preprocess your image, apply different intensity thresholds, and save your analysis in an intuitive format.


**Required Fiji Plugins**

Before running the macro, ensure the following plugins are installed and up to date:
1. Trainable Weka Segmentation - Pre-installed in Fiji
2. Noise2Void (N2V) - Optional preprocessing step, denoising using deep learning
3. Template Matching - Optional preprocessing step, slice alignment

Go to Help → Update... Click Manage Update Sites, and enable CSBDeep and Template_Matching. Then,  Apply Changes, and restart Fiji.


**Use of Macro**

1. Download the macro file
2. Save F_Fo_macro_combined.ijm from this repository.
3. Open Fiji, then go to: Plugins → Macros → Run… and select the macro file.
4. Select the image to run the analysis on. 

You can try the macro using the sample time-lapse image provided here: https://drive.google.com/drive/u/2/folders/12Kj8ol_rpForezNu8eSBeFmZKQFcjKAJ

6. Follow the on-screen dialogs.

