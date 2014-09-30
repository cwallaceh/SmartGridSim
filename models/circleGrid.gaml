/**
 *  CircleGrid
 *  Author: Priscila Angulo
 *			Carl W. Handlin
 *  Description:
 * 	Icons made by Freepik from www.flaticon.com is licensed under CC BY 3.0
 */

model circleGrid

/* Insert your model definition here */

global {
	graph general_graph;
	float totalenergy_smart <- 0.0;
	float totalenergy_nonsmart <- 0.0;
	int time_step <- 0; //748;
	
	int grid_width <- 200;
	int grid_height <- 200;

    int num_houses <- 27;
    int num_transformers <- 9;
    int num_lines <- 3;
    int num_generator <- 1;
    
    float degree_house <- (360 / num_houses); 
	float degree_transformer <- (360 / num_transformers);
	float degree_lines <- (360 / num_lines);
	
    int radius_house <- 55;
    int radius_transformer <- 30;
    int radius_lines <- 15;
    int radius_appliance <- 4;

    int min_household_profile_id;
    int max_household_profile_id;
    
    // MySQL connection parameter
	map<string, string>  MySQL <- [
    'host'::'10.20.217.219',
    'dbtype'::'MySQL',
    'database'::'smartgrid_demandprofiles', // it may be a null string
    'port'::'3306',
    'user'::'smartgrid',
    'passwd'::'smartgrid'];
    
    init {
            create agentDB number: 1;
			ask agentDB{
				do get_household_profiles_ids;	
			}
			create house number: num_houses ;
			create transformer number: num_transformers;
			create powerline number: num_lines;
			create generator number: num_generator;
			do build_graph;
    }
    
    action build_graph {
	  	general_graph <- graph([]);
	  	loop gn over: generator {
	  		loop pl over: powerline {
	  			create edge_agent with: [shape::link({gn.my_x, gn.my_y}::{pl.my_x, pl.my_y})] returns: edges_created;
	  			add edge:(gn::pl)::first(edges_created) to: general_graph;
	  			ask(powerline(pl)){
	  				my_generator_index <- generator(gn).my_index;
	  			}
	  		}
	  		
	  	}
	  	
	  	loop pl_2 over: powerline {
	  		ask pl_2{
	  			do get_my_transformers;	
	  		}
	  		loop tr over: (pl_2.my_transformers) {
	  			create edge_agent with: [shape::link({pl_2.my_x, pl_2.my_y}::{tr.my_x, tr.my_y})] returns: edges_created;
	  			add edge:(pl_2::tr)::first(edges_created) to: general_graph;
	  			ask(transformer(tr)){
	  				my_powerline_index <- powerline(pl_2).my_index;
	  			}
	  		}
	  	} 
	  	
	  	loop tr_2 over: transformer{
	  		ask tr_2{
	  			do get_my_houses;	
	  		}
	  		loop hs over: (tr_2.my_houses) {
	  			create edge_agent with: [shape::link({tr_2.my_x, tr_2.my_y}::{hs.my_x, hs.my_y})] returns: edges_created;
	  			add edge:(tr_2::hs)::first(edges_created) to: general_graph;
	  			ask house(hs){
	  				my_transformer_index <- transformer(tr_2).my_index;
	  			}
	  		}
	  	} 
	  	//write general_graph;
	 }
	 
	 reflex restart_energy_and_time{
	 	totalenergy_smart <- 0.0;
	 	totalenergy_nonsmart <- 0.0;
	 	
	 	loop gn over: generator {
	 		gn.demand  <- 0.0;
	 	}
	 	
	 	loop pl over: powerline {
	 		pl.demand  <- 0.0;
	 	}
	 	
	 	loop tr over: transformer {
	 		tr.demand  <- 0.0;
	 	}
	 	if(time_step = 1439)
	 	{
	 		time_step <- 0;
	 	}
	 	else
	 	{
	 		time_step <- time_step + 1;
	 	}
 	}	  
}

//AgentDB
species agentDB parent: AgentDB { 
	float get_coordinate_x (int radius, int index, float degree){
		return ((radius *(cos(index*degree))) + (grid_width/4));
	}
	
	float get_coordinate_y (int radius, int index, float degree){
		return ((radius *(sin(index*degree))) + (grid_height/4));
	}
	
	action check_db_connection{
    	if (self testConnection(params:MySQL)){
        	write "Connection is OK" ;
		}else{
        	write "Connection is false" ;
		}
    }
	
	action get_household_profiles_ids
	{
		do connect (params: MySQL);
		
		list<list> profileMin <- list<list> ( self select(select:"SELECT min(id_household_profile) FROM household_profiles;"));
		min_household_profile_id <- int (profileMin[2][0][0]);
		
		list<list> profileMax <- list<list> ( self select(select:"SELECT max(id_household_profile) FROM household_profiles;"));
		max_household_profile_id <- int (profileMax[2][0][0]);
	} 
	
	init{
		do check_db_connection;
	}
}

//House
species house parent: agentDB {
    int house_size <- 4;
    int my_index <- house index_of self;
    int my_transformer_index;
    int houseprofile <- rnd(max_household_profile_id - min_household_profile_id) + min_household_profile_id; //598
    int num_appliances;
    
    list<smart_appliance> my_appliances <- [];
    list<list> list_appliances_db;
    file my_icon <- file("../images/House.gif");
    float demand <- 0.0;
    
    float my_x <- get_coordinate_x(radius_house, my_index, degree_house);
    float my_y <- get_coordinate_y(radius_house, my_index, degree_house);
    
    float degree_appliance;
            
    aspect base {
		draw sphere(house_size) color: rgb('blue') at: {my_x , my_y, 0 } ;
	}
	
	aspect icon {
        draw my_icon size: house_size at: {my_x , my_y, 0 } ;
        draw string(demand) size: 3 color: rgb("black") at: {my_x , my_y, 0 };
    }
	
	action get_my_appliances{
		ask agentDB{
			myself.list_appliances_db <- list<list> (self select(select:"SELECT DISTINCT a.id_appliance, a.appliance_description FROM appliances a JOIN appliances_profiles ap ON a.id_appliance = ap.id_appliance WHERE ap.id_household_profile = "+ myself.houseprofile +" AND a.isSmart = 1;"));	
		}
		
		num_appliances <- length( (list_appliances_db[2]) );
		degree_appliance <- (360 / (num_appliances + 1) ); //+1 because of other loads
		
 		loop i from: 1 to: num_appliances{
 			create smart_appliance number: 1 returns: appliance_created;
			ask appliance_created{
				appliance_id <- int (myself.list_appliances_db[2][i-1][0]);
				appliance_name <- string (myself.list_appliances_db[2][i-1][1]);
				houseprofile <-  myself.houseprofile;
				do get_energy_day;
			}
 	  		add smart_appliance(appliance_created) to: my_appliances;
 	  	}
 	  	
 	  	create other_loads number: 1 returns: other_loads_created;
 	  	ask other_loads_created{
 	  		houseprofile <-  myself.houseprofile;
 	  		do get_energy_day;
 	  	}
 	  	
	}
	
	reflex get_demand{
		write("house: " + my_index + " transformer: " + my_transformer_index + " house demand: " + demand);
		transformer(my_transformer_index).demand <- transformer(my_transformer_index).demand + demand;
	}
	
	init{
		do get_my_appliances;
		write("house_index: " + my_index + " house_profile: " + houseprofile);
	}
	
//Smart Appliances  (subspecies of house)
	species smart_appliance parent: agentDB {
		int appliance_size <- 2;
		int my_appliance_index <- smart_appliance index_of self;
		float my_appliance_x <- house(host).my_x + (radius_appliance *(cos(my_appliance_index*degree_appliance))); 
		float my_appliance_y <- house(host).my_y + (radius_appliance *(sin(my_appliance_index*degree_appliance)));
		file my_icon <- file("../images/Appliance.gif") ;
		string appliance_name;
		int appliance_id;
		int houseprofile;
		list<list> energy;
		float current_demand;
		
		//int policy <- rnd(3) + 1;
		//int type <- rnd_choice(["Refrigerator", "Washermachine", "Dishwasher"]); 
		//int demand_pattern <- 1; //todo: list per slot of time the amount of power it will consume
		
		//reflex consume when: energy > 0 {
	    //}
	    
	    reflex getdemand{
			//write ("house_index: "+my_index+" appliance_index: "+my_appliance_index+" demand: " + energy[2][time_step][0]);
		 	current_demand <- (float (energy[2][time_step][0]));
		 	
	 		house(host).demand <- 0.0;
	 	
		 	house(host).demand <- house(host).demand + current_demand;
		 	totalenergy_smart <- totalenergy_smart + current_demand;
		 	/*if (current_demand != 0.0)
		 	{
		 		write("time: "+time_step+" house_index: "+my_index+" appliance_index: "+my_appliance_index+" current_demand: " + current_demand + " demand: " + demand);
		 	}*/
		}
		
		aspect appliance_base {
			draw sphere(appliance_size) color: rgb('purple') at:{my_appliance_x, my_appliance_y, 0};
		}
		
		aspect appliance_icon {
        	draw my_icon size: appliance_size at:{my_appliance_x, my_appliance_y, 0};
        	draw string(current_demand) size: 3 color: rgb("black") at:{my_appliance_x, my_appliance_y, 0};
    	}
    	
    	action get_energy_day{
    		ask agentDB{
				myself.energy <- list<list> (self select(select:"SELECT energy FROM appliances_profiles WHERE id_appliance = "+myself.appliance_id+" AND id_household_profile = "+myself.houseprofile+" ORDER BY time;"));	
			}
    	}
	}

//Other loads (subspecies of house)
	species other_loads parent: agentDB {
		int appliance_size <- 2;
		int houseprofile;
		int my_appliance_index <- house(host).num_appliances;
		float my_appliance_x <- house(host).my_x + (radius_appliance *(cos(my_appliance_index*degree_appliance))); 
		float my_appliance_y <- house(host).my_y + (radius_appliance *(sin(my_appliance_index*degree_appliance)));
		file my_icon <- file("../images/Appliance.gif") ;
		list<list> energy;
		float current_demand;
		
		reflex getdemand{
			current_demand <- (float (energy[2][time_step][0]));
			 	
		 	house(host).demand <- house(host).demand + current_demand;
		 	totalenergy_nonsmart <- totalenergy_nonsmart + current_demand;
		 	/*if (current_demand != 0.0)
		 	{
		 		write("time: "+time_step+" house_index: "+my_index+" appliance_index: other_loads current_demand: " + current_demand + " demand: " + demand);
		 	}*/
		}
			
		
		aspect appliance_icon {
        	draw my_icon size: appliance_size color:rgb("blue")  at:{my_appliance_x, my_appliance_y, 0};
        	draw string(current_demand) size: 3 color: rgb("black") at:{my_appliance_x, my_appliance_y, 0};
    	}
    	
    	action get_energy_day{
    		ask agentDB{
				myself.energy <- list<list> (self select(select:"SELECT SUM(energy) energy, time FROM appliances_profiles WHERE id_household_profile = "+myself.houseprofile+" AND id_appliance NOT IN (SELECT id_appliance FROM appliances WHERE isSmart = 1) GROUP BY time ORDER BY time;"));	
			}
    	}	
	}	
}

//Transformers
species transformer parent: agentDB {
    int transformer_size <- 4;
    int my_index <- transformer index_of self;
    int my_powerline_index;
    list<house> my_houses <- [];
    file my_icon <- file("../images/Transformer.gif") ;
    float demand;
    
    float my_x <- get_coordinate_x(radius_transformer, my_index, degree_transformer);
    float my_y <- get_coordinate_y(radius_transformer, my_index, degree_transformer);
	
	float distance <- ceil((radius_house-radius_transformer)/cos(degree_house)) + 1;
	
    aspect base {
		draw sphere(transformer_size) color: rgb('green') at: {my_x , my_y, 0 } ;
	}
	
	aspect icon {
        draw my_icon size: transformer_size at: {my_x , my_y, 0 } ;
    }
	
	action get_my_houses{
		loop hs over: (species(house)) {
			if ( sqrt( (hs.my_x - my_x)^2 + (hs.my_y - my_y)^2 ) <= distance )
			{
				add hs to: my_houses;
			} 
    	}
    }
    
    reflex get_demand{
    	write("transformer: " + my_index + " powerline: " + my_powerline_index + " demand: " + demand);
    	powerline(my_powerline_index).demand <- powerline(my_powerline_index).demand + demand;
    }
}

//Power lines
species powerline parent: agentDB {
    int lines_size <- 7;
    int my_index <- powerline index_of self;
    int my_generator_index;
	list<transformer> my_transformers <- [];
    file my_icon <- file("../images/PowerLines.gif") ;
    float demand;
    
    float my_x <- get_coordinate_x(radius_lines, my_index, degree_lines);
    float my_y <- get_coordinate_y(radius_lines, my_index, degree_lines);
    
    float distance <- ceil((radius_transformer-radius_lines)/cos(degree_transformer)) + 1;
    
    aspect base {
		draw sphere(lines_size) color: rgb('yellow') at: {my_x , my_y, 0 } ;
	}
	
	aspect icon {
        draw my_icon size: lines_size at: {my_x , my_y, 0 } ;
    }
	
	action get_my_transformers{
		loop tr over: (species(transformer)) {
			if ( sqrt( (tr.my_x - my_x)^2 + (tr.my_y - my_y)^2 ) <= distance )
			{
				add tr to: my_transformers;
			} 
    	}
    }
    
    reflex get_demand{
    	write("powerline: " + my_index + " generator: " + my_generator_index + " demand: " + demand);
    	generator(my_generator_index).demand <- generator(my_generator_index).demand + demand;
    }
}

//Generator
species generator parent: agentDB {
	int generator_size <- 10;
	int my_index <- generator index_of self;
	list<powerline> my_lines update:(list (species(powerline)));
	float my_x <- (grid_width/4);
    float my_y <- (grid_height/4);
    file my_icon <- file("../images/PowerPlant.gif") ;
    float demand;
       
	aspect base {
		draw sphere(generator_size) color: rgb('red') at: {my_x , my_y , 0 } ;			
	}
	
	aspect icon {
        draw my_icon size: generator_size at: {my_x , my_y, 0 } ;
    }
    
    reflex get_demand{
    	write("generator: " + my_index + " demand: " + demand);
    }	
}

//Graph
species edge_agent {
    aspect base {
            draw shape color: rgb('black');
    }
}

//Land
grid land width: grid_width height: grid_height neighbours: 4 {
	rgb color <- rgb('white'); 
}

//Experiment
experiment test type: gui {
    parameter "Number of houses: " var: num_houses min: 4 max: 100 category: "House" ;
    
    output {
            display main_display type: opengl {
            		grid land;
                    species house aspect: icon{
						species smart_appliance aspect: appliance_icon;
						species other_loads aspect: appliance_icon;
					}
                    species transformer aspect: icon;
                    species powerline aspect: icon;
                    species generator aspect: icon;
                    species edge_agent aspect: base;
            }
            display chart_display {
  					chart "Total demand" type: series {
  						data "smart demand" value: totalenergy_smart color: rgb('red') ;
  						data "non-smart demand" value: totalenergy_nonsmart color: rgb('blue') ;
					}
			}
		    display house_chart_display {
					chart "House demand" type: series {
						loop hs over: house {
  							data "house" + hs + " demand" value: house(hs).demand color: rnd_color(255) ;
  						}
					}
    		}
    		display transformer_chart_display {
					chart "Transformer demand" type: series {
						loop tr over: transformer {
  							data "transformer" + tr + " demand" value: transformer(tr).demand color: rnd_color(255) ;
  						}
					}
    		}
    		display powerline_chart_display {
					chart "Powerlines demand" type: series {
						loop pl over: powerline {
  							data "Powerline" + pl + " demand" value: powerline(pl).demand color: rnd_color(255) ;
  						}
					}
    		}
	}
}