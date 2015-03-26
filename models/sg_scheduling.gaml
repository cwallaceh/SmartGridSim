/**
 *  CircleGrid
 *  Author: Priscila Angulo
 *			Carl W. Handlin
 *  Description:
 * 	Icons made by Freepik from www.flaticon.com is licensed under CC BY 3.0
 *	https://creativecommons.org/licenses/by/3.0/
 */

model sg_scheduling

/* Insert your model definition here */

global {
	//int debug <- 1;
	int cycle_length <- 1439;
	int debug_agentdb <- 0;
	int debug_house <- 0;
	int debug_transformer <- 0;
	int debug_powerline <- 0;
	int debug_generator <- 0;
	int print_results <- 0;
	
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
	
    int radius_house <- 50;
    int radius_transformer <- 30;
    int radius_lines <- 15;
    int radius_appliance <- 4;

    int min_household_profile_id;
    int max_household_profile_id;
    
    float base_price <- 1.00; //per kwh
    float power_excess <- 0.00;
    float generator_step_value <- 10.0;
    float price_factor <- 1.01; //this value is used to mutiply or divide the base_price depending on production increase or decrease
    
    float transformer_power_capacity <- 22.0; //KW
    float powerline_power_capacity <- 66.0; //KW
    float generator_max_production <- 198.0; //KW
    float generator_base_production <- 5.0; //KW
    float generator_current_production <- 40.0; //KW
    
    float max_smart_capacity <- 0.22;//(rnd(10)/100) + 0.45; //between 45 and 55%
    
    /* 
    float transformer_power_capacity <- 20.0; //KW
    float powerline_power_capacity <- 60.0; //KW
    float generator_max_production <- 180.0; //KW
    float generator_base_production <- 5.0; //KW
    float generator_current_production <- 40.0; //KW
    
    float max_smart_capacity <- 0.215;//(rnd(10)/100) + 0.45; //between 45 and 55%
    */
    
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
	 		gn.demand  <- 0.0;
	 	}
	 	
	 	loop pl over: powerline {
	 		pl.demand  <- 0.0;
	 	}
	 	
	 	loop tr over: transformer {
	 		tr.demand  <- 0.0;
	 	}
	 	if(time_step = cycle_length)
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
		if (debug_agentdb = 1)
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
	
	action recursive_combinations (int r, list<int> elements, list<int> combination, int device_id, int type)
    {
    	int length_elements <- length(elements);
    	
    	if (r = 1)
		{
			loop i from: 0 to: (length_elements - 1)
			{
				list<int> new_combination <- [];
				new_combination <- new_combination + combination;
				new_combination <- new_combination + elements[i];
								
				switch type{
					match 0 //type house
					{
						add new_combination to: house(device_id).all_combinations;
					}
					match 1 //type transfomer
					{
						add new_combination to: transformer(device_id).all_combinations;
					}
					match 2 //type powerline
					{
						add new_combination to: powerline(device_id).all_combinations;		
					}
					match 3 //type generator
					{
						add new_combination to: generator(device_id).all_combinations;	
					}
				}
				
			}  			
		}
    	else{	
	    	loop i from: 0 to: (length_elements - r)    
	    	{
    			list<int> new_combination <- [];
    			new_combination <- new_combination + combination;
    			new_combination <- new_combination + elements[i]; 
    			
    			list<int> new_elements <- [];
    			loop j from: i+1 to: (length_elements - 1)
    			{
    				add	elements[j] to: new_elements;
    			} 
    			
    			do recursive_combinations( r-1, new_elements, new_combination, device_id, type );
	    	} 
    	}
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
    int houseprofile <- my_index + 1; //rnd(max_household_profile_id - min_household_profile_id) + min_household_profile_id; //598
    int num_appliances;
    float smart_budget; 
    list<int> pending_smart_appliances <- [];
    list<list> combinations_power_sum_tick;
	list<list> combinations_bids_sum_tick;
	list<float> power_day_plan <- [];
	list<float> temp_power_day_plan <- [];
	int bid_start_time <- -1;
	float used_base_price <- 0.0;
	
    list<list> all_combinations;
    int better_combination_index;
    float better_combination_bid;
    float total_bid <- 0.0;
    float total_power;
    bool enough_budget <- true;
    
    list<int> my_smart_appliances <- [];
    list<list> list_appliances_db;
    file my_icon <- file("../images/House.gif");
    float demand <- 0.0;
    
    float my_x <- get_coordinate_x(radius_house, my_index, degree_house);
    float my_y <- get_coordinate_y(radius_house, my_index, degree_house);
    
    float degree_appliance;
    int priority_to_assign;
            
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
		list<int> priorities <- []; 
		smart_budget <- (rnd(10)/10 + 13) * num_appliances;
		
		loop i from: 0 to: (num_appliances - 1){
			add (i+1) to: priorities;
		}
		
 		loop i from: 1 to: num_appliances{
 			create smart_appliance number: 1 returns: appliance_created;
 			
 			priority_to_assign <- one_of(priorities);
 			remove priority_to_assign from: priorities;   

			ask appliance_created{
				appliance_id <- int (myself.list_appliances_db[2][i-1][0]);
				appliance_name <- string (myself.list_appliances_db[2][i-1][1]);
				priority <- myself.priority_to_assign;
				houseprofile <-  myself.houseprofile;
				do get_power_day;
			}
 	  	}
 	  	
 	  	loop ap over: (members of_species smart_appliance){
 	  		add ap.my_appliance_index to: my_smart_appliances;
 	  	}
 	  	
 	  	create other_loads number: 1 returns: other_loads_created;
 	  	ask other_loads_created{
 	  		houseprofile <-  myself.houseprofile;
 	  		do get_power_day;
 	  	}
 	  	
	}
	 
	reflex get_demand{
		if (debug_house = 1)
		{
			write("house: " + my_index + " transformer: " + my_transformer_index + " house demand: " + demand);
		}
		
		//for this step the house only has the sum of other loads demand 
		transformer(my_transformer_index).demand <- transformer(my_transformer_index).demand + demand;
		
		do scheduling;
		pending_smart_appliances <- [];
		
		if (time_step = cycle_length and print_results = 1)
		{
			int powerline_index <- transformer(my_transformer_index).my_powerline_index;
			write("SMARTBUDGET;Powerline" + powerline_index + ";Transformer" + my_transformer_index + ";House" + my_index + ";" + smart_budget);
			write("ENOUGHBUDGET;Powerline" + powerline_index + ";Transformer" + my_transformer_index + ";House" + my_index + ";" + enough_budget);
		}
	}
	
	action scheduling{
		do select_appliances;
		do schedule;
		do calculate_bid_power;
	}
	
	//if not all appliances are in budget right now, select combination that max priorities sum
	action select_appliances{
		all_combinations <- [];
		
		loop ap over: my_smart_appliances{
			if (smart_appliance(ap).got_energy = false and smart_appliance(ap).enough_time = true)
			{
				add ap to: pending_smart_appliances;
			}
		}
		
		list<int> elements <- pending_smart_appliances;
		list<int> combination <- [];
		int num_elements <- length(elements);
		bool found_comb <- false;
		
		int i <- 0;
		if (num_elements > 0){
			i <- num_elements;
			loop while: (found_comb = false and i > 0){
				all_combinations <- [];
				do recursive_combinations(i, elements, combination, my_index, 0);
				
				int num_comb_elements <- length(all_combinations);
				if (num_comb_elements > 0)
				{
					
					float best_sum_bid <- 0.0;
					float best_sum_power <- 0.0;
					int best_sum_priority <- -1;
					int best_comb_index <- -1;
								
					int num_appliances_comb <- 0;

					loop comb over: all_combinations{
						num_appliances_comb <- length(list<int>(comb));
						if (num_appliances_comb > 0)
						{
							float sum_energy <- 0.0;
							float sum_power <- 0.0;
							float sum_bid <- 0.0;
							int sum_priority <- 0;
							int sum_time <- 0;
					
							loop ap over: list<int>(comb){
								sum_energy <- sum_energy + sum(smart_appliance(ap).energy);
								sum_power <- sum_power + sum(smart_appliance(ap).power);
								sum_priority <- sum_priority + smart_appliance(ap).priority;
								int length_time <- length(smart_appliance(ap).energy);
								sum_time <- sum_time + length_time; 
							}
							
							sum_bid <- sum_energy * base_price;
							
							if(sum_bid <= smart_budget and sum_priority > best_sum_priority and sum_time < (cycle_length - time_step) ){
								best_sum_bid <- sum_bid;
								best_sum_power <- sum_power;
								best_sum_priority <- sum_priority; 
								best_comb_index <- all_combinations index_of comb;	
							}
						}
					}
					
					if(best_comb_index >= 0){
						found_comb <- true;
						better_combination_bid <- best_sum_bid;
						better_combination_index <- best_comb_index;
						total_bid <- best_sum_bid;
						total_power <- best_sum_power;
					}
					else{
						better_combination_bid <- 0.0;
						better_combination_index <- -1;
						total_bid <- 0.0;
						total_power <- 0.0;
					}
				}

				i <- i-1;
			}
		}
		else{
			better_combination_bid <- 0.0;
			better_combination_index <- -1;
			total_bid <- 0.0;
			total_power <- 0.0;
		}
	}
		 
	action schedule{
		temp_power_day_plan <- [];
		temp_power_day_plan <- power_day_plan;
		
		if (better_combination_index >= 0)
		{
			int length_comb <- length(all_combinations[better_combination_index]);
			int length_time <- 0;
			if(length_comb > 0)
			{
				loop ap over: all_combinations[better_combination_index]{
					int length_time_ap <- length(smart_appliance(ap).power);
					length_time <- length_time + length_time_ap;
				}
			}
			
			int next_plan_index <- -1;
			int index <- time_step;
			loop while: (next_plan_index < 0 and index <= cycle_length ){
				if(temp_power_day_plan[index] <= 0.0)
				{
					next_plan_index <- index;
				}
				index <- index + 1;
			}
			
			if ( next_plan_index >= 0 and (cycle_length - next_plan_index) >= length_time ) //enough time in plan
			{
				int i <- next_plan_index;
				bid_start_time <- i;
				loop ap over: all_combinations[better_combination_index]{
					smart_appliance(ap).start_time <- i; //assing start time
					loop pow over: (smart_appliance(ap).power){
						temp_power_day_plan[i] <- temp_power_day_plan[i] + pow;	
						i <- i + 1;
					}
				}
			}
			else{ //not enough time in plan, backwards filling
				int i <- cycle_length - length_time;
				bid_start_time <- i;
				loop ap over: all_combinations[better_combination_index]{
					smart_appliance(ap).start_time <- i;
					loop pow over: (smart_appliance(ap).power){
						temp_power_day_plan[i] <- temp_power_day_plan[i] + pow;	
						i <- i + 1;
					}
				}
			}
		}
		
	}
	
	action calculate_bid_power{
		combinations_power_sum_tick <- [];
		combinations_bids_sum_tick <- [];
		
		if (better_combination_index >= 0)
		{
			int length_combs <- length(all_combinations);
			loop i from: 0 to: (length_combs - 1)
			{
				add [] to: combinations_power_sum_tick;
				add [] to: combinations_bids_sum_tick;
			}
			
			loop i from: 0 to: (bid_start_time - time_step - 1)
			{
				add 0.0 to: combinations_power_sum_tick[better_combination_index];
				add 0.0 to: combinations_bids_sum_tick[better_combination_index];	
			}
			
			loop ap over: all_combinations[better_combination_index]{
				int length_power <- length(smart_appliance(ap).power);
				if (length_power > 0)
				{
					loop j from: 0 to: (length_power - 1)
					{
						add smart_appliance(ap).power[j] to: combinations_power_sum_tick[better_combination_index];
						add smart_appliance(ap).energy[j] * base_price to: combinations_bids_sum_tick[better_combination_index];	
					}	
				}
			}
			
			used_base_price <- base_price;
		}
	}
	
	action assign_power
    {
    	//reducir presupuesto
    	if (debug_house = 1)
		{
    		write("**ASSIGNED POWER House: " + my_index + "previous smart_budget: " + smart_budget + " spent money: " + total_bid + " final budget: " + (smart_budget - total_bid) );
    	}
    	smart_budget <- smart_budget - total_bid;
    	
    	power_day_plan <- [];
		power_day_plan <- temp_power_day_plan;
		
    	loop ap over: all_combinations[better_combination_index]
    	{
    		smart_appliance(ap).got_energy <- true;
    		smart_appliance(ap).used_base_price_app <- used_base_price;
    	}
    	
    }
   
	init{
		do get_my_appliances;
		
		loop i from: 0 to: cycle_length{
			add 0.0 to: power_day_plan;
		}
		
		if (debug_house = 1)
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
			current_power <- (float (energy[2][time_step][1]));
			current_demand <- current_power;

			house(host).demand <- 0.0;
		 	house(host).demand <- house(host).demand + current_demand;
		 	totalenergy_nonsmart <- totalenergy_nonsmart + current_demand;

			if (print_results = 1){
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
	species smart_appliance  parent: agentDB {
		int appliance_size <- 1;
		int my_appliance_index <- smart_appliance index_of self;
		float my_appliance_x <- house(host).my_x + (radius_appliance *(cos(my_appliance_index*degree_appliance))); 
		float my_appliance_y <- house(host).my_y + (radius_appliance *(sin(my_appliance_index*degree_appliance)));
		file my_icon <- file("../images/Appliance.gif") ;
		string appliance_name;
		int appliance_id;
		int houseprofile;
		list<list> energyandpower;
		list<float> energybid;
		list<float> energy;
		list<float> power;
		float current_demand;
		int priority; //the higher the number the higher the priority
		bool got_energy <- false;
		bool zero_power <- false;
		bool enough_time <- true;
		int energy_index <- 0;
		int length_energy;
		int start_time <- -1;
		float used_base_price_app <- 0.0;

	    reflex getdemand{
	    	int transfomer_index <- house(host).my_transformer_index;
			int powerline_index <- transformer(transfomer_index).my_powerline_index;
	    	
	    	if (got_energy = true and length_energy > 0 and energy_index < length_energy and start_time <= time_step and zero_power = false)
	    	{

	    		if (debug_house = 1)
				{
	    			write ("house_index: " + my_index + " appliance_index: " + my_appliance_index + " demand: " + power[energy_index]);
			 	}

			 	current_demand <- power[energy_index];
			 	house(host).demand <- house(host).demand + current_demand;
			 	totalenergy_smart <- totalenergy_smart + current_demand;
			 	
			 	if (print_results = 1){
				 	write("" + time_step + ";SMARTPOWER;Powerline" + powerline_index + ";Transformer" + transfomer_index + ";House" + my_index + ";SmartAppliance" + my_appliance_index + ";" +power[energy_index]);
				 	write("" + time_step + ";SMARTMONEY;Powerline" + powerline_index + ";Transformer" + transfomer_index + ";House" + my_index + ";SmartAppliance" + my_appliance_index + ";" +used_base_price_app);
			 	}
			 	
			 	energy_index <- energy_index + 1;
	    	}
	    	else 
	    	{
	    		if (print_results = 1){
		    		write("" + time_step + ";SMARTPOWER;Powerline" + powerline_index + ";Transformer" + transfomer_index + ";House" + my_index + ";SmartAppliance" + my_appliance_index + ";0.0");
				 	write("" + time_step + ";SMARTMONEY;Powerline" + powerline_index + ";Transformer" + transfomer_index + ";House" + my_index + ";SmartAppliance" + my_appliance_index + ";0.0");
			 	}
			 	
	    		if ( got_energy = false and zero_power = false) {
		    		if ( enough_budget = true and ((cycle_length) - time_step) <= length_energy ){
		    			enough_time <- false;
		    		}
		    	}
	    	
	    	}
	    	
	    	if(time_step = cycle_length and print_results = 1)
	    	{
	    		
	    		if (zero_power = true)
	    		{
	    			write("GOTENERGY;Powerline" + powerline_index + ";Transformer" + transfomer_index + ";House" + my_index + ";SmartAppliance" + my_appliance_index + ";true");
	    			write("ENOUGHBUDGETAPP;Powerline" + powerline_index + ";Transformer" + transfomer_index + ";House" + my_index + ";SmartAppliance" + my_appliance_index + ";true");
	    			write("ENOUGHTIME;Powerline" + powerline_index + ";Transformer" + transfomer_index + ";House" + my_index + ";SmartAppliance" + my_appliance_index + ";true");
	    		}
	    		else
	    		{
	    			write("GOTENERGY;Powerline" + powerline_index + ";Transformer" + transfomer_index + ";House" + my_index + ";SmartAppliance" + my_appliance_index + ";" + ((got_energy = true) ? "true" : "false"));
	    			write("ENOUGHBUDGETAPP;Powerline" + powerline_index + ";Transformer" + transfomer_index + ";House" + my_index + ";SmartAppliance" + my_appliance_index + ";" + ((got_energy = false and enough_time = true) ? "false" : "true"));
	    			write("ENOUGHTIME;Powerline" + powerline_index + ";Transformer" + transfomer_index + ";House" + my_index + ";SmartAppliance" + my_appliance_index + ";" + ((enough_time = true) ? "true" : "false"));
	    		}
	    		
	    	}
		}
		
		aspect appliance_base {
			draw sphere(appliance_size) color: rgb('purple') at:{my_appliance_x, my_appliance_y, 0};
		}
		
		aspect appliance_icon {
			if(got_energy = true)
			{
				draw sphere(appliance_size) color: rgb("red") at:{my_appliance_x, my_appliance_y, 0};
			}
			else if(zero_power = true)
			{
				draw sphere(appliance_size) color: rgb("purple") at:{my_appliance_x, my_appliance_y, 0};
			}
			else if(enough_budget = false)
			{
				draw sphere(appliance_size) color: rgb("cyan") at:{my_appliance_x, my_appliance_y, 0};
			}
			else if(enough_time = false)
			{
				draw sphere(appliance_size) color: rgb("green") at:{my_appliance_x, my_appliance_y, 0};
			}
			else
			{
				draw sphere(appliance_size) color: rgb("gray") at:{my_appliance_x, my_appliance_y, 0};
			}
    	}
    	
    	action get_power_day{
    		ask agentDB{
				myself.energyandpower <- list<list> (self select(select:"SELECT energy, power FROM appliances_profiles WHERE id_appliance = "+myself.appliance_id+" AND id_household_profile = "+myself.houseprofile+" AND power != 0 ORDER BY time;"));
			}
			do get_energy_power;
    	}
    	
    	action get_energy_power{
    		int num_rows <- length( (energyandpower[2]) );
    		if (num_rows > 0){
	    		loop i from: 0 to: (num_rows - 1){
	    			add (float(energyandpower[2][i][0])) to: energy;
	    			add (float(energyandpower[2][i][1])) to: power;
	    		}
    		}
    		else{
    			zero_power <- true;
    		}
    		length_energy <- length(energy);
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
    list<float> available_nonsmart_power_per_tick;
    list<float> available_smart_power_per_tick;
    list<list> combinations_power_sum_tick;
	list<list> combinations_bids_sum_tick;
	list<float> combinations_bids_sum;
	list<list> all_combinations;
    int better_combination_index;
    float better_combination_bid;
    
    float my_x <- get_coordinate_x(radius_transformer, my_index, degree_transformer);
    float my_y <- get_coordinate_y(radius_transformer, my_index, degree_transformer);
	
	float distance <- ceil((radius_house-radius_transformer)/cos(degree_house)) + 1;
	
	init{
		loop i from: 0 to: cycle_length{
			float smart_capacity <- transformer_power_capacity * max_smart_capacity;
			add transformer_power_capacity - smart_capacity to: available_nonsmart_power_per_tick;
			add smart_capacity to: available_smart_power_per_tick; 
		}
	}
	
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
    	if (debug_transformer = 1)
		{
			write("transformer: " + my_index + " powerline: " + my_powerline_index + " demand: " + demand);
		}
		
		do combinatorial_auction;
		
    	powerline(my_powerline_index).demand <- powerline(my_powerline_index).demand + demand;
    	if (print_results = 1){
    		write("" + time_step + ";Transformer" + my_index + ";exceed_flag;" + (demand - transformer_power_capacity ) );
    	}
    }
    
    action combinatorial_auction{
    	do get_combinations;
    	do get_combinations_sum;
    	do remove_exceeded_combinations;
    	do get_best_combination;
    }
    
	action get_combinations{
		all_combinations <- [];
		list<int> combination <- [];
		list<int> elements <- [];
		
		loop hs over: list<int>(my_houses)
		{
			if house(hs).better_combination_index != -1
			{
				add hs to: elements;
			}
		}
		
		int num_elements <- length(elements);
		if (num_elements > 0){
			loop i from:1 to: num_elements{
				do recursive_combinations(i, elements, combination, my_index, 1);	
			}
			if (debug_transformer = 1)
			{
				write("Transformer: " + my_index + " elements: " + elements);
				write("Transformer: " + my_index + " combinations: " + all_combinations);
			}
		}
		else if (debug_transformer = 1)
		{
			write("Transformer: " + my_index + " no more pending houses");
		}
	}
    
    action get_combinations_sum{
    	combinations_power_sum_tick <- [];
    	combinations_bids_sum_tick <- [];
    	
		int combination_index <- -1;
		loop comb over: all_combinations{
			add [] to: combinations_power_sum_tick;
			add [] to: combinations_bids_sum_tick;
			combination_index <- combination_index + 1;
			
			int max_index_container <- -1;
			loop hs over: comb{
		  		int hs_better_combination_index <- house(hs).better_combination_index;
		  		int num_rows <- length(house(hs).combinations_power_sum_tick[hs_better_combination_index]);
		  		if (num_rows > 0)
		  		{
			  		loop i from: 0 to: num_rows - 1 {
			  			if (max_index_container < i)
			  			{
			  				add house(hs).combinations_power_sum_tick[hs_better_combination_index][i] to: combinations_power_sum_tick[combination_index];
			  				add house(hs).combinations_bids_sum_tick[hs_better_combination_index][i] to: combinations_bids_sum_tick[combination_index];
			  				max_index_container <- max_index_container + 1; 
			  			}
			  			else
			  			{
			  				combinations_power_sum_tick[combination_index][i] <- float(combinations_power_sum_tick[combination_index][i]) + float(house(hs).combinations_power_sum_tick[hs_better_combination_index][i]);
			  				combinations_bids_sum_tick[combination_index][i] <- float(combinations_bids_sum_tick[combination_index][i]) + float(house(hs).combinations_bids_sum_tick[hs_better_combination_index][i]);
			  			}
			  		}
		  		}
			}
		}
		if (debug_transformer = 1)
		{
			write("Transformer: " + my_index + " combinations_power_sum_tick: " + combinations_power_sum_tick);
			write("Transformer: " + my_index + " combinations_bids_sum_tick: " + combinations_bids_sum_tick);
    	}
    }
    
    action remove_exceeded_combinations
    {
    	list<int> exceeded_combinations <- [];
    	int length_combinations <- length(all_combinations);
    	if (length_combinations > 0)
    	{
	    	loop comb from: 0 to: length_combinations - 1
	    	{
	    		int length_powerlist <- length(combinations_power_sum_tick[comb]);
	    		if (length_powerlist > 0)
	    		{ 
	    			bool exceeds <- false;
		    		int i <- 0;
		    		loop while: (exceeds = false) and (i < length_powerlist)
		    		{
		    			if (time_step < cycle_length)
		    			{
			    			if (float(combinations_power_sum_tick[comb][i]) > available_smart_power_per_tick[time_step + i])
			    			{
			    				exceeds <- true;
			    				add comb to: exceeded_combinations;
			    			}
						}
		    			i <- i + 1;
		    		}
		    		if (exceeds = true) //erases power list and bid list
		    		{
		    			combinations_power_sum_tick[comb] <- [];
		    			combinations_bids_sum_tick[comb]<- [];
		    		}
		    	}
	    	}
			if (debug_transformer = 1)
			{    	
	    		write("Transformer: " + my_index + " exceeded combinations: " + exceeded_combinations);
	    		write("Transformer: " + my_index + " in competence combinations: " + combinations_power_sum_tick);
	    	}
    	}
    }
    
    action get_best_combination
    {
    	combinations_bids_sum <- [];
    	int length_bidlist <- length(combinations_bids_sum_tick);
    	if (length_bidlist > 0)
    	{
	    	loop comb from: 0 to: length_bidlist-1
	    	{
	    		add sum(list<float>(combinations_bids_sum_tick[comb])) to: combinations_bids_sum;
	    	}
    		better_combination_bid <- max(combinations_bids_sum);
    		if (better_combination_bid > 0.0)
	    	{
		    	better_combination_index <- combinations_bids_sum last_index_of better_combination_bid;
		    	
		    	if (debug_transformer = 1)
				{
					write("Transformer: " + my_index + " combinations_bids_sum: " + combinations_bids_sum);
		    		write("Transformer: " + my_index + " better_combination_index: " + better_combination_index + " better_combination: " + better_combination_bid );
				}
			}
			else {
    			better_combination_index <- -1;
			}
    	}
    	else
    	{
    		better_combination_bid <- 0.0;
    		better_combination_index <- -1;
    	}
    }
    
    action assign_power
    {
    	if (better_combination_bid > 0){
	    	int length_rows <- length(combinations_power_sum_tick[better_combination_index]);
	    	if ( length_rows > 0)
	    	{
		    	loop i from: 0 to: length_rows - 1
		    	{
		    		available_smart_power_per_tick[time_step + i] <- available_smart_power_per_tick[time_step + i] + float(combinations_power_sum_tick[better_combination_index][i]);
		    	}
	    	}
	    	
	    	loop hs over: all_combinations[better_combination_index]
	    	{
	    		ask house(hs){
	    			do assign_power;
	    		}	
	    	}    
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
    float demand;
    list<float> available_nonsmart_power_per_tick;
    list<float> available_smart_power_per_tick;
    list<list> combinations_power_sum_tick;
	list<list> combinations_bids_sum_tick;
	list<float> combinations_bids_sum;
	list<list> all_combinations;
	int better_combination_index;
    
    float my_x <- get_coordinate_x(radius_lines, my_index, degree_lines);
    float my_y <- get_coordinate_y(radius_lines, my_index, degree_lines);
    
    float distance <- ceil((radius_transformer-radius_lines)/cos(degree_transformer)) + 1;
    
    init{
		loop i from: 0 to: cycle_length{
			float smart_capacity <- powerline_power_capacity * max_smart_capacity;
			add powerline_power_capacity - smart_capacity to: available_nonsmart_power_per_tick;
			add smart_capacity to: available_smart_power_per_tick; 
		}
	}
    
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
    	if (debug_powerline = 1)
		{
			write("powerline: " + my_index + " generator: " + my_generator_index + " demand: " + demand);
		}
		
		do combinatorial_auction;
		
    	generator(my_generator_index).demand <- generator(my_generator_index).demand + demand;
    	
    	if (print_results = 1){
    		write("" + time_step + ";Powerline" + my_index + ";exceed_flag;" + ( demand - powerline_power_capacity) );
    	}
    }
    
    action combinatorial_auction{
    	do get_combinations;
    	do get_combinations_sum;
    	do remove_exceeded_combinations;
    	do get_best_combination;
    }
    
	action get_combinations{
		all_combinations <- [];
		list<int> combination <- [];
		list<int> elements <- [];
		
		loop tr over: list<int>(my_transformers)
		{
			if transformer(tr).better_combination_index != -1
			{
				add tr to: elements;
			}
		}
		int num_elements <- length(elements);
		if (num_elements > 0){
			loop i from:1 to: num_elements{
				do recursive_combinations(i, elements, combination, my_index, 2);	
			}
			if (debug_powerline = 1)
			{
				write("Powerline: " + my_index + " elements: " + elements);
				write("Powerline: " + my_index + " combinations: " + all_combinations);
			}
		} else if (debug_powerline = 1)
		{
			write("Powerline: " + my_index + " no more pending transformers");
		}
	}
    
    action get_combinations_sum{
    	combinations_power_sum_tick <- [];
    	combinations_bids_sum_tick <- [];
    	
		int combination_index <- -1;
		loop comb over: all_combinations{
			add [] to: combinations_power_sum_tick;
			add [] to: combinations_bids_sum_tick;
			combination_index <- combination_index + 1;
			
			int max_index_container <- -1;
			loop tr over: comb{
				int transf_better_combination_index <- transformer(tr).better_combination_index;
				int num_rows <- length(transformer(tr).combinations_power_sum_tick[transf_better_combination_index]);
		  		
		  		if (num_rows > 0)
		  		{
		  			loop i from: 0 to: num_rows - 1 {
			  			if (max_index_container < i)
			  			{
			  				add transformer(tr).combinations_power_sum_tick[transf_better_combination_index][i] to: combinations_power_sum_tick[combination_index];
			  				add transformer(tr).combinations_bids_sum_tick[transf_better_combination_index][i] to: combinations_bids_sum_tick[combination_index];
			  				max_index_container <- max_index_container + 1; 
			  			}
			  			else
			  			{
			  				combinations_power_sum_tick[combination_index][i] <- float(combinations_power_sum_tick[combination_index][i]) + float(transformer(tr).combinations_power_sum_tick[transf_better_combination_index][i]);
			  				combinations_bids_sum_tick[combination_index][i] <- float(combinations_bids_sum_tick[combination_index][i]) + float(transformer(tr).combinations_bids_sum_tick[transf_better_combination_index][i]);
			  			}
			  		}
		  		}
			}
		}
		
		if (debug_powerline = 1)
		{
			write("Powerline: " + my_index + " combinations_power_sum_tick: " + combinations_power_sum_tick);
			write("Powerline: " + my_index + " combinations_bids_sum_tick: " + combinations_bids_sum_tick);
    	}
    }
    
    action remove_exceeded_combinations
    {
    	list<int> exceeded_combinations <- [];
    	int length_combinations <- length(all_combinations);
    	if (length_combinations > 0)
    	{
	    	loop comb from: 0 to: length_combinations - 1
	    	{
	    		int length_powerlist <- length(combinations_power_sum_tick[comb]);
	    		if (length_powerlist > 0)
	    		{ 
	    			bool exceeds <- false;
		    		int i <- 0;
		    		loop while: (exceeds = false) and (i < length_powerlist)
		    		{
		    			if (time_step < cycle_length)
		    			{
			    			if (float(combinations_power_sum_tick[comb][i]) > available_smart_power_per_tick[time_step + i])
			    			{
			    				exceeds <- true;
			    				add comb to: exceeded_combinations;
			    			}
		    			}
		    			i <- i + 1;
		    		}
		    		if (exceeds = true) //erases power list and bid list
		    		{
		    			combinations_power_sum_tick[comb] <- [];
		    			combinations_bids_sum_tick[comb]<- [];
		    		}
		    	}
	    	}
	    	if (debug_powerline = 1)
			{
		    	write("Powerline: " + my_index + " exceeded combinations: " + exceeded_combinations);
		    	write("Powerline: " + my_index + " in competence combinations: " + combinations_power_sum_tick);
	    	}
    	}
    }
    
    action get_best_combination
    {
    	combinations_bids_sum <- [];
    	int length_bidlist <- length(combinations_bids_sum_tick);
    	if (length_bidlist > 0)
    	{
	    	loop comb from: 0 to: length_bidlist-1
	    	{
	    		add sum(list<float>(combinations_bids_sum_tick[comb])) to: combinations_bids_sum;
	    	}
	    	
	    	float better_combination <- max(combinations_bids_sum);
	    	if (better_combination > 0.0)
	    	{
		    	better_combination_index <- combinations_bids_sum last_index_of better_combination;
		    	
		    	if (debug_powerline = 1)
				{
					write("Powerline: " + my_index + " combinations_bids_sum: " + combinations_bids_sum);
		    		write("Powerline: " + my_index + " better_combination_index: " + better_combination_index + " better_combination: " + better_combination );
		    	}
			}
			else {
				better_combination_index <- -1;
			}
    	}
    	else {
    		better_combination_index <- -1;
    	}
    }
    
    action assign_power
    {
    	int length_rows <- length(combinations_power_sum_tick[better_combination_index]);
    	if ( length_rows > 0)
    	{
	    	loop i from: 0 to: length_rows - 1
	    	{
	    		available_smart_power_per_tick[time_step + i] <- available_smart_power_per_tick[time_step + i] + float(combinations_power_sum_tick[better_combination_index][i]);
	    	}
    	}
    	
    	loop tr over: all_combinations[better_combination_index]
    	{
    		ask transformer(tr){
    			do assign_power;
    		}	
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
    float demand;
    int finish <- 0;
    list<float> available_nonsmart_power_per_tick;
    list<float> generated_smart_power_per_tick;
    list<float> sold_smart_power_per_tick;
    list<list> combinations_power_sum_tick;
	list<list> combinations_bids_sum_tick;
	list<float> combinations_bids_sum;
	list<list> all_combinations;
	int better_combination_index;
	float highest_smart_demand <- 0.0;
	float mean_smart_demand <- 0.0;
	float median_smart_demand <- 0.0;
	float min_smart_demand <- 0.0;
       
	aspect base {
		draw sphere(generator_size) color: rgb('red') at: {my_x , my_y , 0 } ;			
	}
	
	aspect icon {
        draw my_icon size: generator_size at: {my_x , my_y, 0 } ;
    }
    
    init{
    	loop pl over: (species(powerline)) {
			add pl to: my_lines; 
    	}
    	
    	loop i from: 0 to: cycle_length{
			float smart_capacity <- generator_current_production * max_smart_capacity;
			add generator_current_production - smart_capacity to: available_nonsmart_power_per_tick;
			add smart_capacity to: generated_smart_power_per_tick; 
			add 0 to: sold_smart_power_per_tick;
		}
    }
    
    action recalculate_available_power{
    	loop i from: (time_step + 1) to: cycle_length{
			float smart_capacity <- generator_current_production * max_smart_capacity;
			available_nonsmart_power_per_tick[i] <- generator_current_production - smart_capacity;
			generated_smart_power_per_tick[i] <- smart_capacity;
		}
    }
    
    //step production function
    action production_function_step{ 
    	bool increase_step <- false;
    	bool decrease_step <- false;
		
		if ( ((demand > ( min_smart_demand * max_smart_capacity )) ? demand : ( min_smart_demand * max_smart_capacity )) > generator_current_production)
    	//if ( (demand + (highest_smart_demand * 0.01)) > generator_current_production)
    	//if ( demand > generator_current_production)
	    {
	    	if ((generator_current_production + generator_step_value) <= generator_max_production)
	    	{
	    		generator_current_production <- generator_current_production + generator_step_value;
		     	increase_step <- true;
		     	do recalculate_available_power;
	    	}
	    }
	    else{
	    	float var <- 0.0;
	    	if (time_step < (cycle_length))
	    	{
	    		 var <- generator_current_production - generator_step_value - sold_smart_power_per_tick[time_step+1] ; //considers next tick's sold power 
	    	}
	    	else
	    	{
	    		var <- generator_current_production - generator_step_value;
	    	}
	    	if ( ((demand > ( min_smart_demand * max_smart_capacity )) ? demand : ( min_smart_demand * max_smart_capacity )) < var)
	    	//if ( (demand + (highest_smart_demand * 0.01)) < var)
	    	//if ( demand < var)
		    {
		    	generator_current_production <- generator_current_production - generator_step_value;
		    	decrease_step <- true;
		    	do recalculate_available_power;
		    }	
	    }
	    
	    if (increase_step = true)
	    {
	    	base_price <- base_price * price_factor;
	    }
	    
	    if (decrease_step = true)
	    {
	    	base_price <- base_price / price_factor;
	    }
	    
    }
    
    //linear production function
    action production_function_linear{	
    }
    
    reflex get_demand{
    	if (debug_generator = 1)
		{
			write("smart_power_capacity: " + generated_smart_power_per_tick[time_step]);
			write("generator: " + my_index + " demand: " + demand);
		}
		
		if (print_results = 1){
			write("" + time_step + ";base_price;" + base_price);
			write("" + time_step + ";power_excess;" + power_excess);
		}
		
		do combinatorial_auction;
    }
    
    reflex base_price{
    /*
     * 1 - Considerar ultima cantidad producida y demandada, si esta muy cerca de los limites, aumentar o disminuir produccion
     * 2 - Si la prod aumenta el precio base aumenta, si disminuye, disminuye
     * 3 - ??? si la energia disponible no se ha asignado por completo, bajar el precio y recibir nuevas ofertas
     */
     	power_excess <- generator_current_production - demand;
     	//write("time: " + time_step + " power_excess: " + power_excess + " current_production: " + current_production + " demand: " + demand );
		do production_function_step;
    }
    
    action combinatorial_auction{
    	do get_combinations;
    	do get_combinations_sum;
    	do remove_exceeded_combinations;
    	do get_best_combination;
    	do assign_power;
    }
    
	action get_combinations{
		all_combinations <- [];
		list<int> combination <- [];
		list<int> elements <- [];
		
		loop pl over: list<int>(my_lines)
		{
			if powerline(pl).better_combination_index != -1
			{
				add pl to: elements;
			}
		}
		
		int num_elements <- length(elements);
		if (num_elements > 0){
			loop i from:1 to: num_elements{
				do recursive_combinations(i, elements, combination, my_index, 3);	
			}
			if (debug_generator = 1)
			{
				write("Generator: " + my_index + " elements: " + elements);
				write("Generator: " + my_index + " combinations: " + all_combinations);
			}
		}else if (debug_generator = 1)
		{
			write("Generator: " + my_index + " no more pending powerlines");
		}
	}
    
    action get_combinations_sum{
    	combinations_power_sum_tick <- [];
    	combinations_bids_sum_tick <- [];
    	
		int combination_index <- -1;
		loop comb over: all_combinations{
			add [] to: combinations_power_sum_tick;
			add [] to: combinations_bids_sum_tick;
			combination_index <- combination_index + 1;
			
			int max_index_container <- -1;
			loop pl over: comb{
				int pl_better_combination_index <- powerline(pl).better_combination_index;
				int num_rows <- length(powerline(pl).combinations_power_sum_tick[pl_better_combination_index]);
		  		
		  		if (num_rows > 0)
		  		{
		  			loop i from: 0 to: num_rows - 1 {
			  			if (max_index_container < i)
			  			{
			  				add powerline(pl).combinations_power_sum_tick[pl_better_combination_index][i] to: combinations_power_sum_tick[combination_index];
			  				add powerline(pl).combinations_bids_sum_tick[pl_better_combination_index][i] to: combinations_bids_sum_tick[combination_index];
			  				max_index_container <- max_index_container + 1; 
			  			}
			  			else
			  			{
			  				combinations_power_sum_tick[combination_index][i] <- float(combinations_power_sum_tick[combination_index][i]) + float(powerline(pl).combinations_power_sum_tick[pl_better_combination_index][i]);
			  				combinations_bids_sum_tick[combination_index][i] <- float(combinations_bids_sum_tick[combination_index][i]) + float(powerline(pl).combinations_bids_sum_tick[pl_better_combination_index][i]);
			  			}
			  		}
		  		}
			}
		}
		
		int length_combs <- length(combinations_power_sum_tick);
		if (length_combs > 0){
			list<float> sum_comb <- [];
			loop i from: 0 to: length_combs - 1{
				add sum(list<float>(combinations_power_sum_tick[i])) to: sum_comb;
			}
			highest_smart_demand <- max(sum_comb);
			mean_smart_demand <- mean(sum_comb);
			median_smart_demand <- median(sum_comb);
			min_smart_demand <- min(sum_comb where (each > 0.0));
		}
		
		if (debug_generator = 1)
		{
			write("Generator: " + my_index + " combinations_power_sum_tick: " + combinations_power_sum_tick);
			write("Generator: " + my_index + " combinations_bids_sum_tick: " + combinations_bids_sum_tick);
    	}
    }
    
    action remove_exceeded_combinations
    {
    	list<int> exceeded_combinations <- [];
    	int length_combinations <- length(all_combinations);
    	if (length_combinations > 0)
    	{
	    	loop comb from: 0 to: length_combinations - 1
	    	{
	    		int length_powerlist <- length(combinations_power_sum_tick[comb]);
	    		if (length_powerlist > 0)
	    		{ 
	    			bool exceeds <- false;
		    		int i <- 0;
		    		loop while: (exceeds = false) and (i < length_powerlist)
		    		{
		    			if (time_step < cycle_length)
		    			{
			    			if (float(combinations_power_sum_tick[comb][i]) > (generated_smart_power_per_tick[time_step + i] - sold_smart_power_per_tick[time_step + i]))
			    			{
			    				exceeds <- true;
			    				add comb to: exceeded_combinations;
			    			}
		    			}
		    			i <- i + 1;
		    		}
		    		if (exceeds = true) //erases power list and bid list
		    		{
		    			combinations_power_sum_tick[comb] <- [];
		    			combinations_bids_sum_tick[comb]<- [];
		    		}
		    	}
	    	}
	    	
	    	if (debug_generator = 1)
			{
		    	write("Generator: " + my_index + " exceeded combinations: " + exceeded_combinations);
		    	write("Generator: " + my_index + " in competence combinations: " + combinations_power_sum_tick);
	    	}
    	}
    }
    
    action get_best_combination
    {
    	combinations_bids_sum <- [];
    	int length_bidlist <- length(combinations_bids_sum_tick);
    	if (length_bidlist > 0)
    	{
	    	loop comb from: 0 to: length_bidlist-1
	    	{
	    		add sum(list<float>(combinations_bids_sum_tick[comb])) to: combinations_bids_sum;
	    	}
	    	
	    	float better_combination <- max(combinations_bids_sum);
	    	if (better_combination > 0.0)
	    	{
		    	better_combination_index <- combinations_bids_sum last_index_of better_combination;
		    	
		    	if (debug_generator = 1)
				{
					write("Generator: " + my_index + " combinations_bids_sum: " + combinations_bids_sum);
		    		write("Generator: " + my_index + " better_combination_index: " + better_combination_index + " better_combination: " + better_combination );
		    	}
	    	}
	    	else{
	    		better_combination_index <- -1;
	    	}
    	}
    	else {
    		better_combination_index <- -1;
    	}
    }
    
    action assign_power
    {
    	if (better_combination_index != -1)
    	{
	    	int length_rows <- length(combinations_power_sum_tick[better_combination_index]);
	    	if (length_rows > 0)
	    	{
		    	loop i from: 0 to: length_rows - 1
		    	{
		    		sold_smart_power_per_tick[time_step + i] <- sold_smart_power_per_tick[time_step + i] + float(combinations_power_sum_tick[better_combination_index][i]);
		    	}
	    	}
	    	
	    	loop pl over: all_combinations[better_combination_index]
	    	{
	    		ask powerline(pl){
	    			do assign_power;
	    		}	
	    	}
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
    parameter "Debug House: " var: debug_house min: 0 max: 1 category: "General configuration" ;
    parameter "Debug Transformer: " var: debug_transformer min: 0 max: 1 category: "General configuration" ;
    parameter "Debug Powerline: " var: debug_powerline min: 0 max: 1 category: "General configuration" ;
    parameter "Debug Generator: " var: debug_generator min: 0 max: 1 category: "General configuration" ;
    parameter "Print results: " var: print_results min: 0 max: 1 category: "General configuration" ;
    
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
					}
			}
    		display powerexcess_chart_display {
					chart "Power excess" type: series {
						data "power excess" value: power_excess color: rgb('red') ;
					}
    		}
    		
	}
}
