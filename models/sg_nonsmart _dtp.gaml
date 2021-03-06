/**
 *  CircleGrid
 *  Author: Priscila Angulo
 *			Carl W. Handlin
 *  Description:
 * 	Icons made by Freepik from www.flaticon.com is licensed under CC BY 3.0
 */

model sg_nonsmart_dtp

/* Insert your model definition here */

global {
	int debug <- 0;
	int cycle_length <- 1439;
	int print_results <- 1;
	
	graph general_graph;
	float totalenergy_smart <- 0.0;
	float totalenergy_nonsmart <- 0.0;
	int time_step <- 0;
	
	int grid_width <- 200;
	int grid_height <- 200;

    int num_houses <- 27;
    int num_transformers <- 9;
    int num_lines <- 3;
    int num_generator <- 1;
    
    float degree_house <- (360 / num_houses); 
	float degree_transformer <- (360 / num_transformers);
	float degree_lines <- (360 / num_lines);
	
    int radius_house <- 50;
    int radius_transformer <- 30;
    int radius_lines <- 15;
    int radius_appliance <- 4;

    int min_household_profile_id;
    int max_household_profile_id;
    
    float base_price <- 1.00; //per kwh
    float power_excess <- 0.00;   
    float transformer_power_capacity <- 20.0; //KW
    float powerline_power_capacity <- 60.0; //KW
    float generator_max_production <- 180.0; //KW
    
    float generator_current_production <- 40.0; //KW
	
	string production_function <- "Max"; 
    string price_function <- "Cosine";

    //for cosine price function
    float price_cosine_base <- 1.25;
    float price_cosine_bound <- 0.25;

    //for constant price function
    float price_constant <- 1.0;
    
    // MySQL connection parameter
	map<string, string>  MySQL <- [
    'host'::'localhost',
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
	 
	 reflex restart_power_and_time{
	 	totalenergy_smart <- 0.0;
	 	totalenergy_nonsmart <- 0.0;
	 	
	 	loop gn over: generator {
			gn.demand_smart  <- 0.0;
	 		gn.demand_nonsmart  <- 0.0;
	 	}
	 	
	 	loop pl over: powerline {
	 		pl.demand_smart  <- 0.0;
	 		pl.demand_nonsmart  <- 0.0;

	 	}
	 	
	 	loop tr over: transformer {
	 		tr.demand_smart  <- 0.0;
	 		tr.demand_nonsmart  <- 0.0;
	 	}
	 	if( time_step = ( cycle_length + 1 ))
	 	{
	 		do halt;
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
		if (debug = 1)
		{
	    	if (self testConnection(params:MySQL)){
	        	write "Connection is OK" ;
			}else{
	        	write "Connection is false" ;
			}
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
    int houseprofile <- my_index + 1; // rnd(max_household_profile_id - min_household_profile_id) + min_household_profile_id; //598
    int num_appliances;
    
    list<smart_appliance> my_appliances <- [];
    list<list> list_appliances_db;
    file my_icon <- file("../images/House.gif");
    float demand_smart <- 0.0;
    float demand_nonsmart <- 0.0;
    
    float my_x <- get_coordinate_x(radius_house, my_index, degree_house);
    float my_y <- get_coordinate_y(radius_house, my_index, degree_house);
    
    float degree_appliance;
            
    aspect base {
		draw sphere(house_size) color: rgb('blue') at: {my_x , my_y, 0 } ;
	}
	
	aspect icon {
        draw my_icon size: house_size at: {my_x , my_y, 0 } ;
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
				do get_power_day;
			}
 	  		add smart_appliance(appliance_created) to: my_appliances;
 	  	}
 	  	
 	  	create other_loads number: 1 returns: other_loads_created;
 	  	ask other_loads_created{
 	  		houseprofile <-  myself.houseprofile;
 	  		do get_power_day;
 	  	}
 	  	
	}
	
	reflex get_demand{
		if (debug = 1)
		{
			write("house: " + my_index + " transformer: " + my_transformer_index + " house demand_smart: " + demand_smart);
			write("house: " + my_index + " transformer: " + my_transformer_index + " house demand_nonsmart: " + demand_nonsmart);
		}
		
		transformer(my_transformer_index).demand_nonsmart <- transformer(my_transformer_index).demand_nonsmart + demand_nonsmart;
		transformer(my_transformer_index).demand_smart <- transformer(my_transformer_index).demand_nonsmart + demand_smart;
	}
	
	init{
		do get_my_appliances;
		if (debug = 1)
		{
			write("house_index: " + my_index + " house_profile: " + houseprofile);	
		}
	}

//Other loads (subspecies of house)
	species other_loads parent: agentDB {
		int appliance_size <- 1;
		int houseprofile;
		int my_appliance_index <- house(host).num_appliances;
		float my_appliance_x <- house(host).my_x + (radius_appliance *(cos(my_appliance_index*degree_appliance))); 
		float my_appliance_y <- house(host).my_y + (radius_appliance *(sin(my_appliance_index*degree_appliance)));
		file my_icon <- file("../images/Appliance.gif") ;
		list<list> energy;
		float current_demand;
		float current_power;
		
		reflex getdemand{
			current_power <- (float (energy[2][time_step-1][1]));
			current_demand <- current_power;
			
		 	house(host).demand_nonsmart <- 0.0;
		 	house(host).demand_nonsmart <- house(host).demand_nonsmart + current_demand;
		 	totalenergy_nonsmart <- totalenergy_nonsmart + current_demand;
		 	
		 	if(print_results = 1){
			 	int transfomer_index <- house(host).my_transformer_index;
				int powerline_index <- transformer(transfomer_index).my_powerline_index;
			 	write("" + time_step + ";NONSMARTPOWER;Powerline" + powerline_index + ";Transformer" + transfomer_index + ";House" + my_index + ";NonSmartAppliance" + my_appliance_index + ";" +current_power);
				write("" + time_step + ";NONSMARTMONEY;Powerline" + powerline_index + ";Transformer" + transfomer_index + ";House" + my_index + ";NonSmartAppliance" + my_appliance_index + ";" + (current_power > 0 ? base_price : 0.0));
			}
		}
			
		aspect appliance_icon {
        	draw sphere(appliance_size) color: rgb("blue") at:{my_appliance_x, my_appliance_y, 0};
    	}
    	
    	action get_power_day{
    		ask agentDB{
				myself.energy <- list<list> (self select(select:"SELECT SUM(energy) energy, SUM(power) power, time FROM appliances_profiles WHERE id_household_profile = "+myself.houseprofile+" AND id_appliance NOT IN (SELECT id_appliance FROM appliances WHERE isSmart = 1) GROUP BY time ORDER BY time;"));	
			}
    	}	
	}	

//Smart Appliances  (subspecies of house)
	species smart_appliance parent: agentDB {
		int appliance_size <- 1;
		int my_appliance_index <- smart_appliance index_of self;
		float my_appliance_x <- house(host).my_x + (radius_appliance *(cos(my_appliance_index*degree_appliance))); 
		float my_appliance_y <- house(host).my_y + (radius_appliance *(sin(my_appliance_index*degree_appliance)));
		file my_icon <- file("../images/Appliance.gif") ;
		string appliance_name;
		int appliance_id;
		int houseprofile;
		list<list> energyandpower;
		float current_demand;
		
	    reflex getdemand{
			int transfomer_index <- house(host).my_transformer_index;
			int powerline_index <- transformer(transfomer_index).my_powerline_index;
			 	
		 	current_demand <- (float (energyandpower[2][time_step-1][1]));
	 		
	 		house(host).demand_smart <- 0.0;
			house(host).demand_smart <- house(host).demand_smart + current_demand;
		 	totalenergy_smart <- totalenergy_smart + current_demand;
		 	
		 	if(print_results = 1)
		 	{
			 	write("" + time_step + ";SMARTPOWER;Powerline" + powerline_index + ";Transformer" + transfomer_index + ";House" + my_index + ";SmartAppliance" + my_appliance_index + ";" +current_demand);
				write("" + time_step + ";SMARTMONEY;Powerline" + powerline_index + ";Transformer" + transfomer_index + ";House" + my_index + ";SmartAppliance" + my_appliance_index + ";" + (current_demand > 0 ? base_price : 0.0));	
			}
		}
		
		aspect appliance_base {
			draw sphere(appliance_size) color: rgb('red') at:{my_appliance_x, my_appliance_y, 0};
		}
		
		aspect appliance_icon {
		    draw sphere(appliance_size) color: rgb('red') at:{my_appliance_x, my_appliance_y, 0};
		}
		
    	action get_power_day{
    		ask agentDB{
				myself.energyandpower <- list<list> (self select(select:"SELECT energy, power FROM appliances_profiles WHERE id_appliance = "+myself.appliance_id+" AND id_household_profile = "+myself.houseprofile+" ORDER BY time;"));	
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
    float demand_smart;
    float demand_nonsmart;
    
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
    	if (debug = 1)
		{
			write("transformer: " + my_index + " powerline: " + my_powerline_index + " demand_nonsmart: " + demand_nonsmart);
			write("transformer: " + my_index + " powerline: " + my_powerline_index + " demand_smart: " + demand_smart);
		}
		powerline(my_powerline_index).demand_nonsmart <- powerline(my_powerline_index).demand_nonsmart + demand_nonsmart;
    	powerline(my_powerline_index).demand_smart <- powerline(my_powerline_index).demand_smart + demand_smart;
    	
    	if (print_results = 1){
    		write("" + time_step + ";Transformer" + my_index + ";exceed_flag;" + ( (demand_smart + demand_nonsmart) - transformer_power_capacity ) );
    	}    	
    }
}

//Power lines
species powerline parent: agentDB {
    int lines_size <- 7;
    int my_index <- powerline index_of self;
    int my_generator_index;
	list<transformer> my_transformers <- [];
    file my_icon <- file("../images/PowerLines.gif") ;
    float demand_smart;
    float demand_nonsmart;
    
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
    	if (debug = 1)
		{
			write("powerline: " + my_index + " generator: " + my_generator_index + " demand_smart: " + demand_smart);
			write("powerline: " + my_index + " generator: " + my_generator_index + " demand_nonsmart: " + demand_nonsmart);
		}
    	
		generator(my_generator_index).demand_smart <- generator(my_generator_index).demand_smart + demand_smart;
    	generator(my_generator_index).demand_nonsmart <- generator(my_generator_index).demand_nonsmart + demand_nonsmart;
    	
    	if (print_results = 1){
    		write("" + time_step + ";Powerline" + my_index + ";exceed_flag;" + ( (demand_smart + demand_nonsmart) - powerline_power_capacity) );
    	}
    }
}

//Generator
species generator parent: agentDB {
	int generator_size <- 10;
	int my_index <- generator index_of self;
	list<powerline> my_lines <- []; 
	float my_x <- (grid_width/4);
    float my_y <- (grid_height/4);
    file my_icon <- file("../images/PowerPlant.gif") ;
    float demand_smart;
    float demand_nonsmart;
    
	//production fuction - period production
	list<list> powerproductionperiods_list;
	list<float> powerproductionperiods;
	int production_period <- 3;
	
	//production function - max production
	list<list> powerproductionmax_list;
	float maxpowerproduction;
	
       
	aspect base {
		draw sphere(generator_size) color: rgb('red') at: {my_x , my_y , 0 } ;			
	}
	
	aspect icon {
        draw my_icon size: generator_size at: {my_x , my_y, 0 } ;
    }
    
    action production_function_period{
		int num_rows <- length( (powerproductionperiods_list) );
		if (num_rows > 0){
			int index <- round(floor(floor((time_step-1)/60)/(24/production_period)));
			generator_current_production <- float(powerproductionperiods_list[2][index][1]);
		}
    }
    
    action production_function_max{
		int num_rows <- length( (powerproductionmax_list) );
		if (num_rows > 0){
			generator_current_production <- float(powerproductionmax_list[2][0][0]);
		}
    }
    
    action price_cosine{    	
    	base_price <- ( (price_cosine_bound * -1) * cos( (360 * time_step) /cycle_length ) ) + price_cosine_base; 
    }
    
    action price_constant{
    	base_price <- price_constant;
    }
    
    reflex get_demand{
    	if (debug = 1)
		{
			write("generator: " + my_index + " demand_smart: " + demand_smart);
			write("generator: " + my_index + " demand_nonsmart: " + demand_nonsmart);
		}
		
		if(print_results = 1)
		{
			write("" + time_step + ";base_price;" + base_price);
			write("" + time_step + ";power_excess;" + power_excess);
		}
		
    }
    
    reflex production_and_price{
     	power_excess <- generator_current_production - (demand_smart + demand_nonsmart);
		
		if (production_function = "Max"){
			do production_function_max;	
		}
		else if (production_function = "Period"){
			do production_function_period;
		}
		
		if (price_function = "Cosine"){
			do price_cosine;
		}
		else if (price_function = "Constant"){
			do price_constant;
		}
    }
    
    init {
		loop pl over: (species(powerline)) {
			add pl to: my_lines; 
    	}
		
		ask agentDB{
			myself.powerproductionperiods_list <- list<list> (self select(select:"select hour(a.time) div (24/"+myself.production_period+") period, max(power) power from ( select time, sum(power) power from appliances_profiles group by time ) a group by hour(a.time) div (24/"+myself.production_period+");"));
			myself.powerproductionmax_list <- list<list> (self select(select:"select max(power) power from ( select time, sum(power) power from appliances_profiles group by time ) a ;"));
		}
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
    parameter "Debug?: " var: debug min: 0 max: 1 category: "General configuration" ;
    parameter "Print results: " var: print_results min: 0 max: 1 category: "General configuration" ;
    
    parameter "Production Function: " var: production_function among:["Max","Period"] category: "Power Generation configuration" ; 
    
    parameter "Price Function: " var: price_function among:["Cosine","Constant"] category: "Price function configuration" ;
    parameter "Constant Power price: " var: price_constant  min: 1.0 max: 10.0 category: "Price function configuration" ;
    parameter "Cosine Power price base: " var: price_cosine_base  min: 0.0 max: 10.0 category: "Price function configuration" ;
    parameter "Cosine Power price bound: " var: price_cosine_bound  min: 0.0 max: 10.0 category: "Price function configuration" ;
  
    
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
			
			display smartVsnonsmart_display {
  					chart "Total demand" type: series {
  						data "smart demand" value: totalenergy_smart color: rgb('red') ;
  						data "non-smart demand" value: totalenergy_nonsmart color: rgb('blue') ;
  						data "total demand" value: (totalenergy_smart + totalenergy_nonsmart) color: rgb('purple') ;
  						data "total production" value: generator_current_production color: rgb('black');
					}
			}
			/*
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
    		*/
    		display powerexcess_chart_display {
					chart "Power excess" type: series {
						data "power excess" value: power_excess color: rgb('red') ;
					}
    		}
	}
}