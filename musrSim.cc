#include "musrDetectorConstruction.hh"
#include "musrPhysicsList.hh"
#include "musrPrimaryGeneratorAction.hh"
#include "musrRunAction.hh"
#include "musrEventAction.hh"
#include "musrStackingAction.hh"
#include "musrSteppingAction.hh"
#include "musrSteppingVerbose.hh"

#include "cosmicMuonManager.h"
#include "rootEventSelector.hh"

#include <string>
#include <fstream>
#include <sstream>
#include <iomanip>
#include <cstdlib>

#include "G4RunManager.hh"
#include "G4UImanager.hh"
#include "G4UIterminal.hh"
#ifdef G4UI_USE_TCSH
#include "G4UItcsh.hh"
#endif

#ifndef G4VIS_USE
#define G4VIS_USE
#endif


// The following two lines are needed to cope with the problem of 
// "Error in <TPluginManager::FindHandler>: Cannot find plugin handler for TVirtualStreamerInfo! 
//               Does $ROOTSYS/etc/plugins/TVirtualStreamerInfo exist?"
#include "TROOT.h"
#include "TPluginManager.h"

#include "Randomize.hh"

#ifdef G4VIS_USE
#include "G4VisExecutive.hh"
#include "G4TrajectoryDrawByCharge.hh"    // TS Trajectory drawing by ID or charge
#endif

#include "musrRootOutput.hh"
#include "musrParameters.hh"
#include "musrErrorMessage.hh"

int main(int argc,char** argv) {
    if (argc < 2) {
        G4cout << "Usage: " << argv[0] << " <steering_file.mac> [output_name | idle] [random_seed_offset]" << G4endl;
        G4cout << "  e.g. cd build/run; mkdir -p data; ../musrSim 101.mac" << G4endl;
        return 1;
    }
    G4cout<<"\n\n*************************************************************"<<G4endl;
    G4cout<<" musrSim version 1.0.5 for Geant4.10.3, released on 20 Mar 2017"<<G4endl;
    G4cout<<"      WWW:  https://www.psi.ch/lmu/geant4-simulations"<<G4endl;
    // Choose the random engine (note: /musr/run/randomOption 2 does not work with RanecuEngine)
    CLHEP::HepRandom::setTheEngine(new CLHEP::HepJamesRandom);

    // Verbose output class
    G4VSteppingVerbose::SetInstance(new musrSteppingVerbose);

    // root event selector
    rootEventSelector* my_evtselector_manager = new rootEventSelector();

    // Run manager
    G4RunManager * runManager = new G4RunManager;


    // Create class "myParameters", which is a collection of many different parameters
    G4String steeringFileName=argv[1];
    musrParameters* myParameters = new musrParameters(steeringFileName);

    // Create class "musrErrorMessage"
    musrErrorMessage* myErrorMessage = new musrErrorMessage();

    // Determine the name of the output ROOT file (command line, or /musr/command SetOutputFileName)
    std::string name = "";
    int random_seed_offset = 0;
    int random_seed = 0;
    G4int kept_evt_num = -1;

    if(argc > 2) {
        name = std::string(argv[2]);
        std::cout << "\nmusrSim.cc: Set output ROOT file: " << "data/musrSim_" << atoi(argv[1]) << "_" << name << ".root\n" << std::endl;
    }
    if(argc > 3) random_seed_offset = atoi(argv[3]);
    // Read from macro to customize output ROOT file name
    // Only if the name not specified in argv[2]
    std::ifstream fin(steeringFileName.c_str());
    std::string line;
    while (!(argc>2) && std::getline(fin, line)){
        std::istringstream ss(line);
        std::string cmd1, cmd2, cmd3;
        if (ss >> cmd1 >> cmd2 >> cmd3){
            if (!cmd1.compare("/musr/command") && !cmd2.compare("SetOutputFileName")){
                std::ostringstream output_num;
                output_num << std::setw(3) << std::setfill('0') << atoi(argv[1]);
                if (!cmd3.compare("DEFAULT")) {
                    std::cout << "\nmusrSim.cc: Set default output ROOT file: " <<"data/musrSim_jp" << output_num.str() << ".root\n" << std::endl;
                }
                else {
                    name = cmd3;
                    std::cout << "\nmusrSim.cc: Set output ROOT file: " << "data/musrSim_jp" << output_num.str() << "_" << cmd3 << ".root\n" << std::endl;
                }
            }
            else if (!cmd1.compare("/musr/command") && !cmd2.compare("SetRndSeed")){
                random_seed = atoi(cmd3.c_str());
                std::cout << "musrSim.cc: Set random seed : " << random_seed << std::endl;
            }
            // Set random seed in macro file
            if (!(argc >3) && !cmd1.compare("/musr/command") && !cmd2.compare("SetRndSeedOffset")){
                random_seed_offset = atoi(cmd3.c_str());
                std::cout << "musrSim.cc: Set random seed offset: " << random_seed_offset << std::endl;
            }
            if (!cmd1.compare("/musr/command") && !cmd2.compare("VisualizeEvent")){
                kept_evt_num = atoi(cmd3.c_str());
            }
            if (!cmd1.compare("/musr/command") && !cmd2.compare("rootEventSelector") && !cmd3.compare("on")){
                rootEventSelector* evt_selector = rootEventSelector::GetInstance();
                evt_selector->UseSelector();
                std::cout << "musrSim.cc: Turn on the event selector" << std::endl;
            }
        }
    }

    musrRootOutput* myRootOutput = new musrRootOutput(name);

// The following command is needed to cope with the problem of 
// "Error in <TPluginManager::FindHandler>: Cannot find plugin handler for TVirtualStreamerInfo! 
//               Does $ROOTSYS/etc/plugins/TVirtualStreamerInfo exist?"
//  /* magic line from Rene - for future reference! */
    gROOT->GetPluginManager()->AddHandler("TVirtualStreamerInfo",
                                          "*",
                                          "TStreamerInfo",
                                          "RIO",
                                          "TStreamerInfo()");


    // UserInitialization classes (mandatory)
    // Get the run number from the name of the steering file, if it starts with a number.
    G4int myRunNr=atoi(argv[1]);
    if (myRunNr>0)  {runManager->SetRunIDCounter(myRunNr);}

    musrDetectorConstruction* musrdetector = new musrDetectorConstruction(steeringFileName,random_seed_offset, random_seed);
    runManager->SetUserInitialization(musrdetector);
    runManager->SetUserInitialization(new musrPhysicsList);

#ifdef G4VIS_USE
    // Visualization
    G4VisManager* visManager = new G4VisExecutive;
    visManager->Initialize();
#endif

    // UserAction classes
    runManager->SetUserAction(new musrPrimaryGeneratorAction(musrdetector));
    runManager->SetUserAction(new musrRunAction);
    runManager->SetUserAction(new musrEventAction(kept_evt_num));
    // Initiate musrStackingAction only if optical photons are required (otherwise not needed)
    if (musrParameters::boolG4OpticalPhotons) runManager->SetUserAction(new musrStackingAction);
    runManager->SetUserAction(new musrSteppingAction);

    //Initialize G4 kernel
    runManager->Initialize();

    //get the pointer to the User Interface manager
    G4UImanager * UI = G4UImanager::GetUIpointer();

    // Batch mode: execute the steering file
    {
        G4String command = "/control/execute ";
        G4String fileName = argv[1];
        UI->ApplyCommand(command+fileName);
        if (argc>2) {
            G4String SecondArgument = argv[2];
            if (SecondArgument=="idle") {
                G4UIsession * session = 0;
#ifdef G4UI_USE_TCSH
                session = new G4UIterminal(new G4UItcsh);
#else
                session = new G4UIterminal();
#endif
                G4cout<<"Go to idle state now:"<<G4endl;
                session->SessionStart();
                delete session;
            }
        }
    }

#ifdef G4VIS_USE
    delete visManager;
#endif
    delete my_evtselector_manager;
    delete myRootOutput;
    delete myErrorMessage;
    delete myParameters;
    delete runManager;

    return 0;
}

