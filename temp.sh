cd Loop                                                
  git checkout -b feature/policy-trials                                                                                                                                                    
  git add Loop.xcodeproj/project.pbxproj \               
          Loop/AlternativeDosingPolicies/ \
          Loop/Managers/LoopDataManager.swift \                                                                                                                                            
          "Loop/Managers/Store Protocols/DosingDecisionStoreProtocol.swift" \
          "Loop/View Controllers/InsulinDeliveryTableViewController.swift" \                                                                                                               
          "Loop/View Controllers/StatusTableViewController.swift" \                                                                                                                        
          Loop/Views/DosingStrategySelectionView.swift \
          Loop/Views/DoseDetailView.swift \                                                                                                                                                
          Loop/Views/PolicyComparisonTableViewCell.swift \
          LoopCore/LoopSettings.swift \                                                                                                                                                    
          LoopTests/Managers/LoopDataManagerDosingTests.swift \                                                                                                                            
          LoopTests/ViewModels/BolusEntryViewModelTests.swift
  git commit -m "LLM dosing policy + dose-attribution UI"                                                                                                                                  
  cd ..                                                                                                                                                                                    
                                                                                                                                                                                           
  # --- NightscoutService submodule ---                                                                                                                                                    
  cd NightscoutService                                   
  git checkout -b feature/policy-trials
  git add NightscoutServiceKit/Extensions/StoredSettings.swift
  git commit -m "Add LLMPolicy to AutomaticDosingStrategy name mapping"                                                                                                                    
  cd ..
                                                                                                                                                                                           
  # --- Back in parent LoopWorkspace ---                                                                                                                                                   
  # 'git add Loop LoopKit NightscoutService' records the new submodule commit
  # SHAs (this is what the parent actually tracks):                                                                                                                                        
  git add Loop LoopKit NightscoutService                 
  git add .gitignore                                                          # already staged earlier                                                                                     
  # the scheme deletion is also already staged           
  git commit -m "Wire LLM dosing policy across Loop/LoopKit/NightscoutService submodules"   
