/**
 *  model7
 *  Author: 
 *  Description: Land use simulation Trabui, Vietnam 
 */

model model7

global {
	//file shape_file <- file('../includes/xxx.shp') ;
	file lu_grid_file <- file('../includes/landcover.asc') ;
	file slope_grid_file <- file('../includes/slope_class.asc') ;
	file dem_grid_file <- file('../includes/dem_pilot.asc') ;	
	map colors <- map([1::rgb([178, 180, 176]), 2::rgb([246, 111, 0]), 3::rgb([107, 0, 0]), 4::rgb([249, 0, 255]), 5::rgb([144, 96, 22]), 6::rgb([255, 255, 86]), 7::rgb([19, 114, 38]), 8::rgb("black"), 9::rgb([107, 94, 255]), 10::rgb([43, 255, 255])]);	
	
	int nrOfFarmers <- 100;
	float cellSize <- 0.09;

	//tbd: check this, not clear from documents
	int landuse_maxYearsTilled <- 2;
	int landuse_maxYearsAciaTilled <- 6;
	int landuse_maxYearsFallow <- 5;
	int landuse_maxYearsNoForest <- 5;
	int landuse_maxYearsRegrowthForest <- 10;
	int landuse_maxYearsMediumForest <- 15;	
	int landuse_maxYearsPoorForest <- 7;
	
	int household_type1_max_Acacia <- 1;
	int household_type2_max_Acacia <- 3;
	int household_type3_max_Acacia <- 5;		
	
	float lu_Village <- 2.0;
	//float farmer_Ownershipfraction <- 0.05;	
	float household_min_familysize <- 2.0;
	float household_max_familysize <- 6.0;
	float household_growth_factor <- 0.0;
	float househould_maxInitialDistanceofPlots <- 500.0;
	float househould_maxInitialDistanceofPlotsforAcacia <- 1000.0;
	
	int household_foodNeedPerFamilyMember <- 200;
	
	int rice <- 1;
	int corn <- 2;
	int acacia <- 3;
	int fallow <- 4;
	
	//labor man/day/ha
	
	int labor_Rice <- 200; 
	int labor_PlantAcacia <- 50;
	int labor_HarvestAcacia <- 150;
	int workingDaysPerYear <- 300;
	
	int riceNeed <- 180;
	
	geometry shape <- envelope(lu_grid_file);	
		
	//rice yield
	//not clear what you mean with table 3? 
	//so took a standard value for rice production
	float riceProdMean <- 750.0;
	float riceProdStd  <- 5.00;
	
	// c02 storage
	int co2_rice <- 2700;
	int co2_corn <- 2700;
	int co2_medium <- 50800;
	int co2_poor <- 2700;
	int co2_rich <- 99800;
	int co2_regrowth <- 11800;
	int co2_acacia <- 11800;
	int co2_fallow <- 939;
	
	float rice_carbon_storage <- 0.0;
	float corn_carbon_storage <- 0.0;
	float acacia_carbon_storage <- 0.0;
	float fallow_carbon_storage <- 0.0;
	float regrowth_carbon_storage <- 0.0;
	float poor_carbon_storage <- 0.0;
	float medium_carbon_storage <- 0.0;
	float rich_carbon_storage <- 0.0;
	float total_carbon_storage <- 0.0 ;

	int start_year_simulation <- 2014;
	float climate_effect_2020 <- 0.0240;
	float climate_effect_2050 <- 0.0684;	
	float climate_effect_2070 <- 0.1032;	
	
	init{
  
		ask elevation {grid_value <- grid_value * 5;}  
		float max_val <- elevation max_of (each.grid_value);
		ask elevation {
			float val <- 255 * (1 - grid_value / max_val);
			color <- rgb(val, val,val);
		}
		create household number: nrOfFarmers{}	

	}
	
	reflex calcCo2 when: cycle > 0{
				rice_carbon_storage <-   ((landuse count(each.cropType = rice))/cellSize) * co2_rice;
				corn_carbon_storage <- ((landuse count (each.cropType = corn))/cellSize) * co2_corn;
			 	acacia_carbon_storage <- ((landuse count (each.cropType = acacia))/cellSize) * co2_acacia;				
			 	fallow_carbon_storage <- ((landuse count (each.cropType = fallow and each.yearsCurrentLandUse > 4))/cellSize) * co2_fallow;
				regrowth_carbon_storage <- ((landuse count (each.cropType = 5))/cellSize) * co2_regrowth;		 	
				medium_carbon_storage <- ((landuse count (each.cropType = 6))/cellSize) * co2_medium;
				poor_carbon_storage <- ((landuse count (each.cropType = 7))/cellSize) * co2_poor ;
				rich_carbon_storage <- ((landuse count (each.cropType = 8))/cellSize) * co2_rich;	
				total_carbon_storage <- rice_carbon_storage + corn_carbon_storage +	acacia_carbon_storage +	fallow_carbon_storage + regrowth_carbon_storage + medium_carbon_storage + poor_carbon_storage + rich_carbon_storage; 
	}

} // end global

//entities {
	
	grid landuse file:lu_grid_file neighbors: 8  use_regular_agents: false  use_individual_shapes: true{
		string luname <- "";
		//indicator for the suitability of landuse for growing crops (0 means not suitable at all)
		float suitability <- 0.0;
		
		//indicator that determines the attractiveness of a cell for being cultivated by a farmer
		float attraction <- 0.0;

		//slope will be imported through another grid 
		int slopeclass <- 0;

		
		int cropType <- 0;
		
		//carbonstock depends on land use 
		float carbonStock <- 0.0;
		
		// as it says
		float distanceToFarm <- 0.0;
		
		int nrOfTimesOwned <- 0;
		
		// as it says
		household owner <- nil;
		
		// says if a cell is really owned
		bool registeredOwner <- false;
		
		// can a plot be cultivate anyway (true or false)
		bool canCultivate <- false;
		
		bool cultivated <- false; 
		
		// number of years a cell has the current landuse
		int yearsCurrentLandUse <- 0;
		
		
		init {
			//write "LOADING LANDUSE";
			switch grid_value{
			match 1.0 {
				//water
				set luname <- 'water';
				set cropType <-11;
				set suitability <- 0.0;
				set canCultivate <- false;
			}
			match 2.0 {
				//settlements
				set luname <- 'settlement';
				set cropType <- 12;
				set suitability <- 0.0;
				set canCultivate <- false;
				
			}
			match 3.0 {
				//cropland
				set luname <- 'cropland';
				set cropType <- 9;				
				set suitability <- 1.0;
				set yearsCurrentLandUse <- rnd(landuse_maxYearsNoForest);
				 set canCultivate <- true;
			}
			match 5.0 {
				//grassland
				set luname <- 'grassland';
				set cropType <- 9;				
				set suitability <- 1.0;
				set yearsCurrentLandUse <- rnd(landuse_maxYearsNoForest);
				set canCultivate <- true;
			}
			match 13.0 {
				set luname <- 'forest regrowth';				
				//forest regrowth 
				set cropType <- 5;				
				set suitability <- 0.02;
				set yearsCurrentLandUse <- rnd(landuse_maxYearsRegrowthForest);
				 set canCultivate <- true;
			}
			match 30.0 {
				//forest poor
				set luname <- 'forest poor';
				set cropType <- 7;								
				set suitability <- 0.3;
				set yearsCurrentLandUse <- rnd(landuse_maxYearsPoorForest);
				set canCultivate <- true;
			}
			
			match 56.0 {
				//forest medium
				set luname <- 'forest medium';	
				set cropType <- 6;							
				set suitability <- 0.2;
				set canCultivate <- true;
			}
			match 110.0 {
				//forest rich
				set luname <- 'forest rich';
				set cropType <- 8;				
				set suitability <- 0.1;
				set canCultivate <- true;				
			}
			
			default {set color <- rgb("black");	}

			}
		
		 	do updateColors;
		}
		


	reflex updateStatusOfLandUse{
		switch cropType{

			match fallow {
				if yearsCurrentLandUse >= landuse_maxYearsFallow{
					set canCultivate <- true;
					set cropType <- 9;
					set yearsCurrentLandUse <- 0;
				}
			}
			match 9{
				if yearsCurrentLandUse >= landuse_maxYearsNoForest{
					set canCultivate <- true;
					set cropType <- 5;
					set yearsCurrentLandUse <- 0;
				}
			}
			match 5{
				if yearsCurrentLandUse >= landuse_maxYearsRegrowthForest{
					if flip(0.6){
						set canCultivate <- true;
						set cropType <- 7;
						set yearsCurrentLandUse <- 0;}
				}
			}
			match 7{
				if yearsCurrentLandUse >= landuse_maxYearsPoorForest{
					if flip(0.6){
						set canCultivate <- true;
						set cropType <- 6;
						set yearsCurrentLandUse <- 0;
					}
				}
			}
			match 6{
				if yearsCurrentLandUse >= landuse_maxYearsMediumForest{
					if flip(0.4){
						set canCultivate <- true;
						set cropType <- 8;
						set yearsCurrentLandUse <- 0;
					}
				}		
			}
			
			
		}
		set yearsCurrentLandUse <- yearsCurrentLandUse + 1;

	}	

	reflex updateColor{	
		do updateColors;
	}		
	
	
	action updateColors{
		switch cropType{
			match rice{set color <- rgb('white');}	
			match corn{set color <- rgb('yellow');}
			match acacia{ set color <- rgb('orange');}
			match fallow{set color <-rgb ('magenta');}
			match 5{set color <- rgb(174,209,117);}	
			match 6{set color <- rgb(145,116,47);}
			match 7{set color <- rgb(105,128,69);}	
			match 8{set color <- rgb(235,220,12);}					
			match 9{set color <- rgb(163,123,13);}
			match 11{set color <- rgb("blue");}			
			match 12{set color <- rgb("red");}	
			
			//rice=1, 
			//corn=2, 
			//acacia=3, 
			//fallow =4, 
			//forest_Re =5, 
			//forest_M=6, 
			//forest_P=7, 
			//forest_Rich=8
			//divers cultivatable = 9
			//water = 11
			//urbanized = 12			
		}
			
	}

} // plot
	
 grid slope file: slope_grid_file use_regular_agents: false use_individual_shapes: false{
  	init{
  		write":LOADING SLOPE CLASSES";
  		list<landuse> lu_inside <- landuse inside self;
  			loop lu over: lu_inside{
  				set lu.slopeclass <- grid_value;
  			} 
  	} 	
 }
 
 grid elevation file: dem_grid_file{
 	init {
 		write int(grid_value);
		//color <- colors at int(grid_value);
		grid_value <- grid_value * 100;
	}
 	
 }

species household  {
		list<landuse> currentPlots <- [];
		int nrOfNewPlotsNeeded <- 0 ;
		bool landOwner <- nil; 
		int householdType <- 0;
		float householdSize <- 0.0;
		int householdNrPlots <- 0;
		int householdExpenses <- 0;
		float labourAvailable <- 0.0;
		int householdIncome <- 0;
		int kgFoodPerFamilyMember <- household_foodNeedPerFamilyMember;
		float riceProduction <- 0.0;
		float riceYield <- 0.0 ;
		float riceSaldo <- 0.0;
		float innovative <- 0.5;

		aspect base {
				draw circle(4) color: rgb("black") ; 	
		}

		init{	
			write"CREATING FARMERS";			
			write "Creating farmer:"+name;
			int cnt <- 0;
			
			//take familysize random between max and min
			householdSize <- (household_min_familysize+ rnd(household_max_familysize));
			
			// set labour availability depending on hh size
			if householdSize < 3 {
				labourAvailable <- 2;
			} else {
				labourAvailable <- householdSize - 2;
			}
			
			//locate household random in a village
			location <- any_location_in (one_of(landuse where (landuse(each).grid_value = lu_Village)));
			write "...at location: "+location;
						
			//define type of agent	
			int count <- 0; 
			int chance <- rnd_choice([0.05,0.14,0.81]);
			//write chance;
			switch chance {		 
				match 0 {
					householdNrPlots <- 20/cellSize + rnd(20/cellSize);
					householdType <- 3;
				}
				match 1 {
					householdNrPlots <- 3/cellSize + rnd(2/cellSize); 
					householdType <- 2;
				}
				match 2{
					householdNrPlots <- 1/cellSize + rnd(1/cellSize); 
					householdType <- 1;
				}
			}
			write"...type: "+householdType;
			write "Initiating crops";
		    switch householdType{
		    	 //tbd: define amount of crops (mean and std. def.) as parameters
		    	
		    	// only normal fallow is included 
		    	
		    	match  1{
		    		int nrOfRiceCells <- round(gauss(0.9,0.1) /cellSize);
		    		int nrOfCornCells <- round(gauss(0.65,0.1)/cellSize);
		    		int nrOfAcaciaCells <- round(0.1/cellSize);
		    		int nrOFFallowCells <- 0;
		    		do findNewPlot (nrOfRiceCells, rice,true);
		    		do findNewPlot (nrOfCornCells, corn,true);
		    		do findNewPlot (nrOfAcaciaCells, acacia,true); 	         					         					
	    		}
	    		match 2 {
		    		int nrOfRiceCells <- round(gauss(1.07,0.2) /cellSize);
		    		int nrOfCornCells <- round(gauss(0.75,0.2) /cellSize);
	    			int nrOfAcaciaCells <- round(0.4/cellSize);
	    			int nrOFFallowCells <- (nrOfRiceCells+nrOfCornCells)*3;
		    		do findNewPlot (nrOfRiceCells, rice,true);
		    		do findNewPlot (nrOfCornCells, corn,true);
		    		do findNewPlot (nrOfAcaciaCells, acacia,true);
	    			do findNewPlot (nrOFFallowCells, fallow,true);
    		
	    		}
	    		match 3 {
		    		int nrOfRiceCells <- round(gauss(1.75,0.3) /cellSize);
		    		int nrOfCornCells <- round(gauss(1.70,0.3)/cellSize);
	    			int nrOfAcaciaCells <- round(0.8/cellSize);
	    			int nrOFFallowCells <- (nrOfRiceCells+nrOfCornCells)*3;
		    		do findNewPlot (nrOfRiceCells, rice,true);
		    		do findNewPlot (nrOfCornCells, corn,true);
		    		do findNewPlot (nrOfAcaciaCells, acacia,true);
	    			do findNewPlot (nrOFFallowCells, fallow,true);
	    			
				}
	   		}
		   do calcRiceYield;

		}
	
		reflex updateSocioEconomicState{
			
			//current model only include increase in population. 
			householdSize <- householdSize + (householdSize* household_growth_factor);
						if householdSize > 8{
				householdSize <- householdSize - 2;	
				create household number: 1{}
			}
			
			//to do: calculate revenues of acacia: need to know te market price of Acia 
			//currently there is no financial model included
			
			
		}
		
	
		reflex runALiving{
			write "=======================================================";
			do calcRiceYield;	
			int numberRiceToBeReplaced <- plantandHarvestRice();
			if riceYield > 0 { 
				if riceSaldo < 0{
					riceProduction <- gauss ({riceProdMean, riceProdStd});
					int nrRiceCellsShort <- round(abs(riceSaldo) / (riceProduction * cellSize));
					let nrRiceCellsNeeded <- nrRiceCellsShort + numberRiceToBeReplaced;
					write name+" need: "+nrRiceCellsNeeded+" new rice cells";
					do findNewPlot (nrRiceCellsNeeded, rice,false);
				}
				if riceSaldo > 0{
					write name+" Enough yield: Trying to grow Acia";
					do plantandHarvestAcia;
				}
			}else{
				riceProduction <- gauss ({riceProdMean, riceProdStd});
				int nrRiceCellsNeeded <- round((riceNeed * householdSize)/ (riceProduction * cellSize));
				write name+" Not enough yield:";
				write "...need: "+nrRiceCellsNeeded+" new rice cells (no yield situation)";
				do findNewPlot (nrRiceCellsNeeded, rice,false);
			
			}
		}	
		
			
		int  plantandHarvestRice{
			 list<landuse> riceToBeHarvest <- (currentPlots where (each.cropType = rice and each.yearsCurrentLandUse = landuse_maxYearsTilled));
			 int riceCount <- length (riceToBeHarvest);
			 do setCroptype(riceToBeHarvest, 0, 0 , 0 , riceCount, 0, 0 );
			 return riceCount;
		}

		action plantandHarvestAcia {
		// first calculate how much labor budget the family still has
		 list<landuse> potentialacaciaHarvestList <- currentPlots where (each.cropType = acacia and each.yearsCurrentLandUse >= landuse_maxYearsAciaTilled);
		 int acaciaHarvestCount <- length(potentialacaciaHarvestList);
		 int riceCornCount <-  length (currentPlots where (each.cropType = rice or each.cropType = corn));
		 float laborNeedeRice <- ((riceCornCount * cellSize) *  labor_Rice);
		 float laborNeededAcacia<- ((acaciaHarvestCount * cellSize) * labor_HarvestAcacia);
		 float laborNeeded <- laborNeedeRice + laborNeededAcacia;
		 float laborDaysAvailable <-  (workingDaysPerYear * labourAvailable) - laborNeeded ;
		 float harvestDaysAvailable <- (workingDaysPerYear * labourAvailable) - laborNeedeRice;
		 write "labor needed for: "; 
	 	 write "	rice/corn: 		"+ laborNeedeRice;
		 write " 	acacia: 		"+ laborNeededAcacia;	
		 write "	total: 			"+ laborNeeded;
		 write "labor  available:	"+ laborDaysAvailable; 	 


			if harvestDaysAvailable > 0{
				if harvestDaysAvailable > laborNeededAcacia { 
					harvestDaysAvailable <- laborNeededAcacia;
				}
		 		int numberofCellsToBeHarvested <- round((harvestDaysAvailable / labor_HarvestAcacia)/cellSize);
			 	list<landuse> acaciaToBeHarvested <- numberofCellsToBeHarvested among (potentialacaciaHarvestList);
		 		write "Harvesting max  "+  numberofCellsToBeHarvested+" cells of acacia";
			 	do setCroptype(acaciaToBeHarvested, 0, 0 , 0 , numberofCellsToBeHarvested, 0, 0 );

			 }		 
			 if laborDaysAvailable >= 0 {
					int max_Acacia_Area <- 0;
					switch householdType {
						match 1{
							max_Acacia_Area <- household_type1_max_Acacia;		
						}
						match 2{
							max_Acacia_Area <- household_type2_max_Acacia;		
						}
						match 3{
							max_Acacia_Area <- household_type3_max_Acacia;			
						}		
					 }
		 		float currentAcacia_area <- (length(currentPlots where (each.cropType = acacia))) * cellSize;
		 		float newAcacia_area <- max_Acacia_Area - currentAcacia_area;
		 		if newAcacia_area > 0 {
		 			float possibleAcacia_area <- (laborDaysAvailable / labor_PlantAcacia);
		 			if possibleAcacia_area < newAcacia_area {
		 				newAcacia_area <- possibleAcacia_area;
		 			}

		 			int newAcacia_cells <- round(newAcacia_area / cellSize);
		 			write "Trying to find:" + newAcacia_cells + " new cells for acacia";
		 			do findNewPlot (newAcacia_cells, acacia,false);
		 			//do setCroptype(nil, 0, 0, newAcacia_cells, 0, 0, 0);
		 		}
			 }
		 	
		}
		 	  	
		 				
		//function to calculate yield based on a production
		action calcRiceYield{			   
		    float climateEffectRice <- 0; 
		    //tbc make parameter of it for easy access
		    if cycle > (2070 - start_year_simulation) {climateEffectRice <- climate_effect_2070;}
		    else if cycle > (2050 - start_year_simulation) {climateEffectRice <- climate_effect_2050;}
		    else if cycle > (2020 - start_year_simulation) {climateEffectRice <- climate_effect_2020;}
		
			riceProduction <- gauss ({riceProdMean, riceProdStd});
			float climateEffect <- riceProduction * climateEffectRice;
			riceProduction <- riceProduction - climateEffect;
			int nrRicePlot <- length( currentPlots where (each.cropType = rice) );
			if nrRicePlot > 0 {
				riceYield <- riceProduction * (nrRicePlot * cellSize);
			} else{
				riceYield <- 0.0;
			}
			
			riceSaldo <- riceYield - (riceNeed * householdSize);
		}
		
		
		
		action findNewPlot(int nrOfPlots, int crpType, bool init) {
			//to do: first look in owned cells if there is fallow land available
			list<landuse> potentialCellList <- [];
			list<landuse> newlyCultivated <- [];
			int counter <- 0;
			if init = false{
				if householdType != 1{
					if crpType != acacia{
					 	potentialCellList <- currentPlots where (each.canCultivate = true);
					 }else{
					 	potentialCellList <- currentPlots where (each.canCultivate = true and each.cropType = 5);					 	
					 }
					do calcAttraction(potentialCellList);
					potentialCellList <- reverse(potentialCellList sort_by (each.attraction));
					loop cell over: potentialCellList{
						//write "- "+cell+"; "+cell.attraction;
				  	if counter < nrOfPlots{
					  	cell.distanceToFarm <-  cell distance_to self;
					  	cell.owner <- self;
					  	//cell.nrOfTimesOwned <- cell.nrOfTimesOwned + 1;
					  	create ownedCell number: 1{
					  		location <- (cell.location );	
					  	}
					  	add cell to: newlyCultivated;
					  	counter <- counter + 1;
			 	 	}				
					}
				}
				if householdType = 1 or (counter < nrOfPlots){	
					if crpType != acacia{		
						potentialCellList <- landuse at_distance househould_maxInitialDistanceofPlots where ((each.owner = nil) and (each.canCultivate = true));
					}else{
						potentialCellList <- landuse at_distance househould_maxInitialDistanceofPlotsforAcacia where ((each.owner = nil) and (each.canCultivate = true) and (each.cropType = 5));
					}
					do calcAttraction(potentialCellList);
					potentialCellList <- reverse(potentialCellList sort_by (each.attraction));
					loop cell over: potentialCellList{
					  if counter < nrOfPlots{
				  		cell.distanceToFarm <-  cell distance_to self;
					  	cell.owner <- self;
					  	create ownedCell number: 1{
					  		location <- point(cell.location );	
					  	}
					  	add cell to: newlyCultivated;
					  	counter <- counter + 1;
				 	 }				
					}
				
				}
				switch crpType {
					match rice{
						do setCroptype(newlyCultivated, nrOfPlots, 0, 0, 0, 0, 0);
					}
					match corn{
						do setCroptype(newlyCultivated, 0, nrOfPlots, 0, 0, 0, 0);	
					}
					match acacia{
						do setCroptype(newlyCultivated, 0, 0, nrOfPlots, 0, 0, 0);	
					}
					match fallow {
						do setCroptype(newlyCultivated, 0, 0, 0, nrOfPlots, 0, 0);	
					}
					
				}
			}
			else{					
					write "needed plots for "+ crpType+ ": "+nrOfPlots;
					float distFactor <- 1.0;
					string dummy <- ".";
					loop while: length(potentialCellList) < nrOfPlots{
						househould_maxInitialDistanceofPlots <- househould_maxInitialDistanceofPlots * distFactor;	
						potentialCellList <- landuse at_distance househould_maxInitialDistanceofPlots where (each.owner = nil and (each.cropType = 9));
						write dummy ;
						dummy <- dummy +".";		
						distFactor <- distFactor + 0.01;
					}
		    		//calculate attration
		    		do calcAttraction(potentialCellList);
					potentialCellList <- reverse(potentialCellList sort_by (each.attraction));
					loop cell over: potentialCellList{
			  			if  length(newlyCultivated) < nrOfPlots{
			  				cell.distanceToFarm <-  cell distance_to self;
			  				cell.owner <- self;
			  				create ownedCell number: 1{
			  					location <- point(cell.location );	
			  				}
			  				add cell to: newlyCultivated;
			  				if householdType != 1{
			  					add cell to: currentPlots;
			  					cell.registeredOwner <- true;
			  				}
			  			}					
					}
	    			//reset attraction for plots not yet assigned
	    			loop cell over: potentialCellList{
	    				if cell.owner = nil{
	    					do resetOwnership(cell); 
	    				}
	    			}	
					
					switch crpType {
						match rice{
							do setCroptype(newlyCultivated, nrOfPlots, 0, 0, 0, rnd(landuse_maxYearsTilled) , 0);
						}
						match corn{
							do setCroptype(newlyCultivated, 0, nrOfPlots, 0, 0, rnd(landuse_maxYearsTilled) , 0);	
						}
						match acacia{
							do setCroptype(newlyCultivated, 0, 0, nrOfPlots, 0,rnd(landuse_maxYearsAciaTilled) , 0);	
						}
						match fallow {
							do setCroptype(newlyCultivated, 0, 0, 0, nrOfPlots, 0, rnd(landuse_maxYearsFallow));	
						}				
					}
				}
	    				
				set potentialCellList <- nil;
				//check for the croptype

				
		}	
		
		
		//calculate attraction of each cell withing reach
		action calcAttraction(list<landuse> landuseCollection){
			loop cellCloseToFarm over: landuseCollection{
				//calc attraction
				float distToFarm <- cellCloseToFarm distance_to self;
		    	bool canCalculate <- true;	 
				if  distToFarm <= 0 {
					canCalculate <- false;
				}   
				//write "slope: "+ cellCloseToFarm.slopeclass;
				if 	cellCloseToFarm.slopeclass <= 0 {
					canCalculate <- false;
				} 
				
				if cellCloseToFarm.suitability <= 0 {
					canCalculate <- false;
				}
		    	
		    	if canCalculate {
		    		cellCloseToFarm.attraction <- 1/(distToFarm^0.5) + 1/(cellCloseToFarm.slopeclass^5) + cellCloseToFarm.suitability;
		    	}
		    	else{cellCloseToFarm.attraction <- 0.0;}
		    	
			}	
		}
		
		//function to distribute the different crops of the plots
		action setCroptype(list<landuse> possibleCultivationCells, int nR, int nC, int nA, int nF, int yT, int yF ){
		    			int nrOfRiceCells <- nR;
		    			int nrOfCornCells <- nC;
		    			int nrOfAcaciaCells <- nA;
		    			int nrOFFallowCells <- nF;
		    			if nrOfRiceCells > 0 { 
		         			int riceCellCount <- 0;
		         			loop cell over: possibleCultivationCells{
				 				if riceCellCount < nrOfRiceCells {
		        	 				cell.cropType <- rice;
		        	 				cell.owner <- self;
		        	 				if cell != currentPlots  {
										add cell to: currentPlots;
									}
		        	 				cell.canCultivate <- false;
		        	 				cell.cultivated <- true;
		         					cell.yearsCurrentLandUse <- yT;
			         				riceCellCount <- riceCellCount +1;
		         				}
		         			}
		         		}
		         		//list cornCells <- currentPlots where (each.croptype = 0);
		         		if nrOfCornCells > 0{
		         			int cornCellCount <- 0;
		         			loop cell over: possibleCultivationCells{
		         			 	if (cornCellCount < nrOfCornCells) and (cell.canCultivate = true) {
		         					cell.cropType <- corn;
		         					cell.owner <- self;
									if cell != currentPlots  {
										add cell to: currentPlots;
									}    				
						        	cell.cultivated <- true;
		        	 				cell.canCultivate <- false;						        
		         					cell.yearsCurrentLandUse <- yT;
		         					cornCellCount <- cornCellCount +1;
			         					         				
			         			}
		         			}
		         		}
		         		//assign fallow cells
		         		if nrOFFallowCells > 0{
		         			int fallowCellCount <- 0;
		         			loop cell over: possibleCultivationCells{
		         				if (fallowCellCount < nrOFFallowCells) and (cell.canCultivate = false) {
		         					cell.cropType <- fallow;
		         					cell.owner <- self;
									if cell.registeredOwner = false {
										remove cell from: currentPlots;
										cell.owner <- nil;
									}
			         				
		        	 				cell.cultivated <- false;
		        	 				cell.canCultivate <- false;		        	 			
		         					cell.yearsCurrentLandUse <- yF;
		         					fallowCellCount <- fallowCellCount +1;
		         				}
		         			}
		         		}
		         		//assign acia if possible
		         		//this is through a special procedure because acacia is only found in regrowth forest 
	         			if nrOfAcaciaCells > 0 {
	         				int acaciaCellCount <- 0;
//	         				list possibleAcaciacells <- landuse at_distance househould_maxInitialDistanceofPlotsforAcacia where (each.owner = nil and each.cropType = 5);
//	         				if length(possibleAcaciacells) >0 {
//	         					do calcAttraction(possibleAcaciacells);	
//	         					possibleAcaciacells <- reverse(possibleAcaciacells sort_by (landuse(each).attraction));
	         					loop cell over: possibleCultivationCells{
		         					if  (acaciaCellCount < nrOfAcaciaCells) {
		         						cell.cropType <- acacia;
		         						cell.owner <- self;
		        	 					if cell != currentPlots  {
											add cell to: currentPlots;
										}
			        		 			cell.cultivated <- true;	
		    	    		 			cell.canCultivate <- false;
		        	 					cell.nrOfTimesOwned <- cell.nrOfTimesOwned + 1;
		         						cell.yearsCurrentLandUse <- yT;
		         						cell.distanceToFarm <-  cell distance_to self;
		         						acaciaCellCount <- acaciaCellCount +1;		         			
		         					}
		         				}
		         				//ask possibleAcaciacells{do updateColors;}	
		         		}
		         		ask possibleCultivationCells{do updateColors;}
		} 
	
		//function to do some resetting and updating if cell does not have an owner anymore
		action resetOwnership(landuse cell){	
    			cell.attraction <- 0.0; 
			    list<ownedCell> owned <- agents_inside(cell);
			    loop oc over: owned{
			    	ask oc{
			    		remove all: self from: cell;
			    		do die;
			    	}
			    }
		}
	
	}


//just a stupid solution to quickly show which plots currently have an owner
//todo: find a more elegant solution
species ownedCell{
	reflex checkIfDead{
		do reset;
	}			
	aspect base {
		draw square(30) empty: true color: rgb('black');				
	}
	
	action reset{
		landuse luCheck <- landuse at self.location;
		if luCheck.owner = nil{	
			do die;
		}
	}
}			
		
//}
	

experiment trabui type: gui {
	
	parameter "# of farmers:" var: nrOfFarmers category: "Control Parameters";
	parameter "initial search distance for plots:" var: househould_maxInitialDistanceofPlots category: "Control Parameters";
	parameter "initial search distance for acacia:" var: househould_maxInitialDistanceofPlotsforAcacia category: "Control Parameters";	
	parameter "Max. years cultivated plot:" var: landuse_maxYearsTilled category: "Control Parameters";
	parameter "Max. years fallow:" var: landuse_maxYearsFallow category: "Control Parameters";
	parameter "Max. years no forest:" var: landuse_maxYearsNoForest category: "Control Parameters";	
	parameter "Max. years fallow:" var: landuse_maxYearsFallow category: "Control Parameters";	
	parameter "Max. years acia:" var: landuse_maxYearsAciaTilled category: "Control Parameters";	
	parameter "Max. regrowth forest:" var: landuse_maxYearsRegrowthForest category: "Control Parameters";
	parameter "Max. poor forest:" var: landuse_maxYearsPoorForest category: "Control Parameters";
	parameter "Max. medium forest:" var: landuse_maxYearsMediumForest category: "Control Parameters";	

	
	
	parameter "hh type 1 max ha Acacia:" var: household_type1_max_Acacia category: "Control Parameters";
	parameter "hh type 2 max ha Acacia:" var: household_type2_max_Acacia category: "Control Parameters";
	parameter "hh type 3 max ha Acacia:" var: household_type3_max_Acacia category: "Control Parameters";		
	
	parameter "Min family size:" var: household_min_familysize category: "Control Parameters";
	parameter "Max family size:" var: household_max_familysize category: "Control Parameters";
	parameter "Family growth factor:" var: household_growth_factor category: "Control Parameters";
	parameter "Max distance to rice and corn plots:" var: househould_maxInitialDistanceofPlots category: "Control Parameters";
	parameter "Max distance to acacia plots:" var: househould_maxInitialDistanceofPlotsforAcacia category: "Control Parameters";						

	parameter "Labor req for rice/corn:" var: labor_Rice category: "Control Parameters";
	parameter "Labor req for planting acacia:" var: labor_PlantAcacia category: "Control Parameters";
	parameter "Labor req for harvest acacia:" var: labor_HarvestAcacia category: "Control Parameters";		
	parameter "working days a year:" var: workingDaysPerYear category: "Control Parameters";	
	
	parameter "rice/corn needed per person:" var: riceNeed category: "Control Parameters";		
	parameter "averag rice production:" var: riceProdMean category: "Control Parameters";
	parameter "std dev rice production:" var: riceProdStd category: "Control Parameters";
	
	parameter "start year" var: start_year_simulation category: "Control Parameters";
	parameter "climate effect 2020 (rice)" var: climate_effect_2020 category: "Control Parameters";
	parameter "climate effect 2050 (rice)"  var: climate_effect_2050 category: "Control Parameters";
	parameter "climate effect 2070 (rice)" var: climate_effect_2070 category: "Control Parameters";			
			
	output {
		display area_display{
			chart "landuse" type: series background: rgb ('white') size: {1,0.5} position: {0,0} {
				data "rice" value: landuse count (each.cropType = rice) color: rgb ('pink');
				data "corn" value: landuse count (each.cropType = corn) color: rgb ('yellow');
			 	data "acacia" value: landuse count (each.cropType = acacia) color: rgb ('orange');				
			 	data "fallow" value: landuse count (each.cropType = fallow) color: rgb ('magenta');
				data "regrowth" value: landuse count (each.cropType = 5) color: rgb(174,209,117);		 	
				data "medium" value: landuse count (each.cropType = 6) color: rgb(145,116,47);
				data "poor" value: landuse count (each.cropType = 7) color: rgb(105,128,69);
				data "rich" value: landuse count (each.cropType = 8) color: rgb(235,220,12);												
	 		}
		}
		
		display co2_display{
			chart "CO2 storage" type: series background: rgb ('white') size: {1,0.5} position: {0,0}{
				data "rice" value: rice_carbon_storage color: rgb ('pink');					data "corn" value: corn_carbon_storage color: rgb ('yellow');
		 		data "acacia" value: acacia_carbon_storage color: rgb ('orange');				
		 		data "fallow" value: fallow_carbon_storage color: rgb ('magenta');
				data "regrowth" value: regrowth_carbon_storage color: rgb(174,209,117);		 	
				data "medium" value: medium_carbon_storage color: rgb(145,116,47);
				data "poor" value: poor_carbon_storage color: rgb(105,128,69);
				data "rich" value: rich_carbon_storage color: rgb(235,220,12);	
				data "Total" value: total_carbon_storage color: rgb('red');
			}
 		}
	
//		display socio_display{
//			chart "socio" type: series background: rgb ('white') size: {1,0.5} position: {0,0}{
//				data "# hh" value: count (each.household) color: rgb ('pink');
//			}
// 		}

		display gridWithElevation type: opengl ambient_light: 100 { 
			//grid elevation text: true elevation: true grayscale: true;
			grid elevation elevation: false grayscale: false;
		}
		
		display sim type: opengl {
			grid landuse;
			species household aspect: base;
			species ownedCell aspect: base;

			}
			
		}
	}
