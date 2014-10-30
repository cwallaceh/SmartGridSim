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
	int debug <- 0;
	
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
    int radius_appliance <- 3;

    int min_household_profile_id;
    int max_household_profile_id;
    
    float base_price <- 1.00; //per kwh
    float power_excess <- 0.00;
    
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
	 	write ("totalenergy_smart: " + totalenergy_smart);
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
	
	action recursive_combinations (int r, list<int> elements, list<int> combination, int device_id, int type)
    {
    	//write("do_recursion  r: " + r + " elements: " + elements + " combination: " + combination );
    	int length_elements <- length(elements);
    	
    	if (r = 1)
		{
			loop i from: 0 to: (length_elements - 1)
			{
				list<int> new_combination <- [];
				new_combination <- new_combination + combination;
				new_combination <- new_combination + elements[i];
								
				switch type{
					match 1 //type transfomer
					{
						add new_combination to: transformer(device_id).all_combinations;
						//write("Transformer: " + device_id + " combination: " + new_combination);		
					}
					match 2 //type powerline
					{
						add new_combination to: powerline(device_id).all_combinations;
						//write("Powerline: " + device_id + " combination: " + new_combination);		
					}
					match 3 //type generator
					{
						add new_combination to: generator(device_id).all_combinations;
						//write("Generator: " + device_id + " combination: " + new_combination);		
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
    int houseprofile <- rnd(max_household_profile_id - min_household_profile_id) + min_household_profile_id; //598
    int num_appliances;
    float smart_budget <- rnd(1.0) + 0.5; 
    list<float> appliances_bids_sum;
    list<float> appliances_energy_sum; 
    list<float> appliances_bids_sum_tick <- [];
    list<float> appliances_energy_sum_tick <- [];
    list<float> appliances_power_sum_tick <- [];
    list<int> in_budget_appliances;
    list<int> pending_smart_appliances <- [];
    
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
        draw string(demand) size: 3 color: rgb("black") at: {my_x , my_y, 0 };
    }
	
	action get_my_appliances{
		ask agentDB{
			myself.list_appliances_db <- list<list> (self select(select:"SELECT DISTINCT a.id_appliance, a.appliance_description FROM appliances a JOIN appliances_profiles ap ON a.id_appliance = ap.id_appliance WHERE ap.id_household_profile = "+ myself.houseprofile +" AND a.isSmart = 1;"));	
		}
		
		num_appliances <- length( (list_appliances_db[2]) );
		degree_appliance <- (360 / (num_appliances + 1) ); //+1 because of other loads
		list<int> priorities <- []; 
		
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
 	  		add ap.my_appliance_index to: pending_smart_appliances;	
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
			write("house: " + my_index + " transformer: " + my_transformer_index + " house demand: " + demand);
		}
		
		//for this step the house only has the sum of other loads demand 
		transformer(my_transformer_index).demand <- transformer(my_transformer_index).demand + demand;
		
		do combinatorial_auction;
		//do remove_appliances_non_enough_time;
	}
	
	action combinatorial_auction{
		int num_pending_appliances <- length(pending_smart_appliances);
		appliances_bids_sum_tick <- [];
	  	appliances_energy_sum_tick <- [];
	  	appliances_power_sum_tick <- [];
	  	
		if ( num_pending_appliances > 0)
		{
			loop ap over: pending_smart_appliances { //(members of_species smart_appliance) {
				//if (ap.my_appliance_index in pending_smart_appliances){
	  				add sum(smart_appliance(ap).energybid) to: appliances_bids_sum;
	  				add sum(smart_appliance(ap).energy) to: appliances_energy_sum;
	  			//}
		  	}
		  	
		  	if(sum(appliances_bids_sum) <= smart_budget){
		  		if (debug = 1)
				{
		  			write("House: " + my_index + " all pending smart appliances accepted: " + pending_smart_appliances);
		 		}
		  		loop ap over: pending_smart_appliances {
	  				add ap to: in_budget_appliances;
	  			}	  		
		  	}
		  	else{
		  		if (debug = 1)
				{
		  			write("House: " + my_index + " used budget: " + knapsack(smart_budget, num_pending_appliances ));
		  			write("House: " + my_index + " appliances accepted: " + in_budget_appliances);
		  		}
		  	}
		  	
		  	int max_index_container <- -1;
		  	loop ap over: in_budget_appliances{
		  		//write ("ap: " + ap + " (members of_species smart_appliance): " + (members of_species smart_appliance));
		  		int num_rows <- length( ((members of_species smart_appliance)[ap]).energybid );
		  		if (num_rows > 0)
		  		{
			  		loop i from: 0 to: num_rows - 1 {
			  			//write("House: " + my_index + " appliance: " + ap + " row: " + i + " max_index_container: " + max_index_container);
			  			if (max_index_container < i)
			  			{
			  				add ((members of_species smart_appliance)[ap]).energybid[i] to: appliances_bids_sum_tick;
			  				add ((members of_species smart_appliance)[ap]).energy[i] to: appliances_energy_sum_tick;
			  				add ((members of_species smart_appliance)[ap]).power[i] to: appliances_power_sum_tick;
			  				max_index_container <- max_index_container + 1; 
			  			}
			  			else
			  			{
			  				appliances_bids_sum_tick[i] <- appliances_bids_sum_tick[i] + (((members of_species smart_appliance)[ap]).energybid[i]);
			  				appliances_energy_sum_tick[i] <- appliances_energy_sum_tick[i] + (((members of_species smart_appliance)[ap]).energy[i]);
			  				appliances_power_sum_tick[i] <- appliances_power_sum_tick[i] + (((members of_species smart_appliance)[ap]).power[i]);
			  			}
			  		}
		  		}
		  	}
	  	}
	  	else
	  	{
	  		if (debug = 1)
			{
	  			write("House: " + my_index + " no pending smart appliances");
	  		}
	  	}
	}
	
	float knapsack(float available_budget, int n){
		if (n = 0 or available_budget = 0 )
		{
			return 0.0;
		}
		
		if (appliances_bids_sum[n-1] > available_budget)
		{
			return knapsack(available_budget, n-1);
		}
		else
		{
			list<float> recursive_options <- [];
			add (appliances_energy_sum[n-1] + knapsack( (available_budget - appliances_bids_sum[n-1]) , n-1)) to: recursive_options;
			add (knapsack( available_budget , n-1)) to: recursive_options;
			if (recursive_options[0] > recursive_options[1] )
			{
				add	pending_smart_appliances[n-1] to: in_budget_appliances;
			}
			return max(recursive_options);
		}
		return 0;
	}
	
	action assign_power
    {
    	//reducir presupuesto
    	if (debug = 1)
		{
    		write("House: " + my_index + "previous smart_budget: " + smart_budget + " spent money: " + sum(appliances_bids_sum_tick) + " final budget: " + (smart_budget - sum(appliances_bids_sum_tick)) );
    	}
    	smart_budget <- smart_budget - sum(appliances_bids_sum_tick);
    	
    	//remove appliances that got the energy from the list of pending appliances
    	loop ap over: in_budget_appliances
    	{
    		remove ap from: pending_smart_appliances;
    		smart_appliance(ap).got_energy <- true;
    	}
    	
    	//reassign priorities to pending appliances
    	int num_pending_smart_appliances <- length(pending_smart_appliances);
    	if (num_pending_smart_appliances > 0)
    	{
    		list<int> priorities <- [];
    		int new_priority_to_assign <- 0;
    		
    		loop i from: 1 to: num_pending_smart_appliances {
				add i to: priorities;
			}	
			loop ap over: pending_smart_appliances{
    			new_priority_to_assign <- one_of(priorities);
    			remove new_priority_to_assign from: priorities;
    			smart_appliance(ap).priority <- new_priority_to_assign;
    		}
    	}
    }
	
	reflex remove_appliances_non_enough_time{
		loop ap over: pending_smart_appliances{
			if (smart_appliance(ap).enough_time = false)
			{
				remove ap from: pending_smart_appliances;
			} 
		}
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
			
			house(host).demand <- 0.0;
		 	house(host).demand <- house(host).demand + current_demand;
		 	totalenergy_nonsmart <- totalenergy_nonsmart + current_demand;
		}
			
		aspect appliance_icon {
        	draw my_icon size: appliance_size color:rgb("blue")  at:{my_appliance_x, my_appliance_y, 0};
        	draw string(current_demand) size: 3 color: rgb("black") at:{my_appliance_x, my_appliance_y, 0};
    	}
    	
    	action get_power_day{
    		ask agentDB{
				myself.energy <- list<list> (self select(select:"SELECT SUM(energy) energy, time FROM appliances_profiles WHERE id_household_profile = "+myself.houseprofile+" AND id_appliance NOT IN (SELECT id_appliance FROM appliances WHERE isSmart = 1) GROUP BY time ORDER BY time;"));	
			}
    	}	
	}	

//Smart Appliances  (subspecies of house)
	species smart_appliance  parent: agentDB {
		int appliance_size <- 2;
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
		bool enough_time <- true;
		int energy_index <- 0;
		int length_energy;
		
	    reflex getdemand{
	    	if (got_energy = true and length_energy > 0 and energy_index < length_energy)
	    	{
	    		if (debug = 1)
				{
	    			write ("house_index: " + my_index + " appliance_index: " + my_appliance_index + " demand: " + energy[energy_index]);
			 	}
			 	current_demand <- energy[energy_index];
			 	house(host).demand <- house(host).demand + current_demand;
			 	totalenergy_smart <- totalenergy_smart + current_demand;
			 	
			 	energy_index <- energy_index + 1;
			 	
			 	/*if (current_demand != 0.0)
			 	{
			 		write("time: "+time_step+" house_index: "+my_index+" appliance_index: "+my_appliance_index+" current_demand: " + current_demand + " demand: " + demand);
			 	}*/
	    	}
	    	
	    	else if ( got_energy = false ) {
	    		if ( (1440 - time_step) < length_energy ){
	    			enough_time <- false;
	    		}
	    		else {
	    			do calculate_bid;
	    		}
	    	}
			
		}
		
		aspect appliance_base {
			draw sphere(appliance_size) color: rgb('purple') at:{my_appliance_x, my_appliance_y, 0};
		}
		
		aspect appliance_icon {
        	draw my_icon size: appliance_size at:{my_appliance_x, my_appliance_y, 0};
        	//draw string(current_demand) size: 3 color: rgb("black") at:{my_appliance_x, my_appliance_y, 0};
        	draw string(priority) size: 3 color: rgb("black") at:{my_appliance_x, my_appliance_y, 0};
    	}
    	
    	action get_power_day{
    		ask agentDB{
				myself.energyandpower <- list<list> (self select(select:"SELECT energy, power FROM appliances_profiles WHERE id_appliance = "+myself.appliance_id+" AND id_household_profile = "+myself.houseprofile+" AND power != 0 ORDER BY time;"));
				//myself.power <- list<list> (self select(select:"SELECT power, 0 AS offer FROM appliances_profiles WHERE id_appliance = "+myself.appliance_id+" AND id_household_profile = "+myself.houseprofile+" ORDER BY time;"));
			}
			do get_energy_power_bid;
    	}
    	
    	action get_energy_power_bid{
    		int num_rows <- length( (energyandpower[2]) );
    		//write("houseprofile: " + houseprofile + " num_rows: " + num_rows);
    		if (num_rows > 0){
	    		loop i from: 0 to: (num_rows - 1){
	    			//add (float(energyandpower[2][i][0]) * base_price * priority * (rnd(5)/10 + 0.5)) to: energybid;
	    			add (float(energyandpower[2][i][0])) to: energy;
	    			add (float(energyandpower[2][i][1])) to: power;
	    		}
    		}
    		length_energy <- length(energy);
    		do calculate_bid;
    	}
    	
    	action calculate_bid{
    		energybid <- [];
    		if (length_energy > 0){
    			loop i from: 0 to: (length_energy - 1){
    				add (energy[i] * base_price * priority * (rnd(5)/10 + 0.5)) to: energybid;	
    			}
    		}
    	}
	}


//Smart compressor (subspecies of house)
	//species smart_compressor parent: agentDB{
	//	
	//}

}

//Transformers
species transformer parent: agentDB {
    int transformer_size <- 4;
    int my_index <- transformer index_of self;
    int my_powerline_index;
    list<house> my_houses <- [];
    file my_icon <- file("../images/Transformer.gif") ;
    float demand;
    float power_capacity <- 25.0; //KW
    list<float> available_nonsmart_power_per_tick;
    list<float> available_smart_power_per_tick;
    list<list> combinations_power_sum_tick;
	list<list> combinations_bids_sum_tick;
	list<float> combinations_bids_sum;
	list<list> all_combinations;
    int better_combination_index;
    float max_smart_capacity <- (rnd(5)/100) + 0.15; //between 15 and 20%
    
    float my_x <- get_coordinate_x(radius_transformer, my_index, degree_transformer);
    float my_y <- get_coordinate_y(radius_transformer, my_index, degree_transformer);
	
	float distance <- ceil((radius_house-radius_transformer)/cos(degree_house)) + 1;
	
	init{
		loop i from: 0 to: 1439{
			float smart_capacity <- power_capacity * max_smart_capacity;
			add power_capacity - smart_capacity to: available_nonsmart_power_per_tick;
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
    	if (debug = 1)
		{
			write("transformer: " + my_index + " powerline: " + my_powerline_index + " demand: " + demand);
		}
		
		do combinatorial_auction;
		
    	powerline(my_powerline_index).demand <- powerline(my_powerline_index).demand + demand;
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
		list<int> elements <- list<int>(my_houses);
		int num_elements <- length(elements);
		loop i from:1 to: num_elements{
			do recursive_combinations(i, elements, combination, my_index, 1);	
		}
		if (debug = 1)
		{
			write("Transformer: " + my_index + " elements: " + elements);
			write("Transformer: " + my_index + " combinations: " + all_combinations);
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
				int num_rows <- length(house(hs).appliances_power_sum_tick);
		  		if (num_rows > 0)
		  		{
			  		loop i from: 0 to: num_rows - 1 {
			  			//write("Transformer: " + my_index  + " comb: " + comb + " House: " + hs + " row: " + i + " max_index_container: " + max_index_container);
			  			if (max_index_container < i)
			  			{
			  				add house(hs).appliances_power_sum_tick[i] to: combinations_power_sum_tick[combination_index];
			  				add house(hs).appliances_bids_sum_tick[i] to: combinations_bids_sum_tick[combination_index];
			  				max_index_container <- max_index_container + 1; 
			  			}
			  			else
			  			{
			  				combinations_power_sum_tick[combination_index][i] <- float(combinations_power_sum_tick[combination_index][i]) + (house(hs).appliances_power_sum_tick[i]);
			  				combinations_bids_sum_tick[combination_index][i] <- float(combinations_bids_sum_tick[combination_index][i]) + (house(hs).appliances_bids_sum_tick[i]);
			  			}
			  		}
		  		}
			}
		}
		if (debug = 1)
		{
			write("Transformer: " + my_index + " combinations_power_sum_tick: " + combinations_power_sum_tick);
			write("Transformer: " + my_index + " combinations_bids_sum_tick: " + combinations_bids_sum_tick);
    	}
    }
    
    action remove_exceeded_combinations
    {
    	list<int> exceeded_combinations <- [];
    	int length_combinations <- length(all_combinations);
    	loop comb from: 0 to: length_combinations - 1
    	{
    		int length_powerlist <- length(combinations_power_sum_tick[comb]);
    		if (length_powerlist > 0)
    		{ 
    			bool exceeds <- false;
	    		int i <- 0;
	    		loop while: (exceeds = false) and (i < length_powerlist)
	    		{
	    			if (time_step < 1439)
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
		if (debug = 1)
		{    	
    		write("Transformer: " + my_index + " exceeded combinations: " + exceeded_combinations);
    		write("Transformer: " + my_index + " in competence combinations: " + combinations_power_sum_tick);
    	}
    }
    
    action get_best_combination
    {
    	combinations_bids_sum <- [];
    	int length_bidlist <- length(combinations_bids_sum_tick);
    	loop comb from: 0 to: length_bidlist-1
    	{
    		add sum(list<float>(combinations_bids_sum_tick[comb])) to: combinations_bids_sum;
    	}
    	float better_combination <- max(combinations_bids_sum);
    	better_combination_index <- combinations_bids_sum last_index_of better_combination;
    	
    	if (debug = 1)
		{
			write("Transformer: " + my_index + " combinations_bids_sum: " + combinations_bids_sum);
    		write("Transformer: " + my_index + " better_combination_index: " + better_combination_index + " better_combination: " + better_combination );
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
    	
    	loop hs over: all_combinations[better_combination_index]
    	{
    		ask house(hs){
    			do assign_power;
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
    float power_capacity <- 75.0; //KW
    list<float> available_nonsmart_power_per_tick;
    list<float> available_smart_power_per_tick;
    list<list> combinations_power_sum_tick;
	list<list> combinations_bids_sum_tick;
	list<float> combinations_bids_sum;
	list<list> all_combinations;
	int better_combination_index;
    float max_smart_capacity <- (rnd(5)/100) + 0.15; //between 15 and 20%
    
    float my_x <- get_coordinate_x(radius_lines, my_index, degree_lines);
    float my_y <- get_coordinate_y(radius_lines, my_index, degree_lines);
    
    float distance <- ceil((radius_transformer-radius_lines)/cos(degree_transformer)) + 1;
    
    init{
		loop i from: 0 to: 1439{
			float smart_capacity <- power_capacity * max_smart_capacity;
			add power_capacity - smart_capacity to: available_nonsmart_power_per_tick;
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
    	if (debug = 1)
		{
			write("powerline: " + my_index + " generator: " + my_generator_index + " demand: " + demand);
		}
		
		do combinatorial_auction;
		
    	generator(my_generator_index).demand <- generator(my_generator_index).demand + demand;
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
		list<int> elements <- list<int>(my_transformers);
		int num_elements <- length(elements);
		loop i from:1 to: num_elements{
			do recursive_combinations(i, elements, combination, my_index, 2);	
		}
		if (debug = 1)
		{
			write("Powerline: " + my_index + " elements: " + elements);
			write("Powerline: " + my_index + " combinations: " + all_combinations);
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
				//write("Transformer: " + tr + " transf_better_combination_index: " + transf_better_combination_index);
				//write("Transformer: " + tr + " elem better comb: " + transformer(tr).combinations_power_sum_tick[transf_better_combination_index]);
		  		
		  		if (num_rows > 0)
		  		{
		  			loop i from: 0 to: num_rows - 1 {
			  			//write("Powerline: " + my_index  + " comb: " + comb + " Transformer: " + tr + " row: " + i + " max_index_container: " + max_index_container);
			  			if (max_index_container < i)
			  			{
			  				//write("Powerline: " + my_index  + " comb: " + comb + " Transformer: " + tr + " row: " + i + " "+ transformer(tr).combinations_power_sum_tick[transf_better_combination_index][i]);
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
		if (debug = 1)
		{
			write("Powerline: " + my_index + " combinations_power_sum_tick: " + combinations_power_sum_tick);
			write("Powerline: " + my_index + " combinations_bids_sum_tick: " + combinations_bids_sum_tick);
    	}
    }
    
    action remove_exceeded_combinations
    {
    	list<int> exceeded_combinations <- [];
    	int length_combinations <- length(all_combinations);
    	loop comb from: 0 to: length_combinations - 1
    	{
    		int length_powerlist <- length(combinations_power_sum_tick[comb]);
    		if (length_powerlist > 0)
    		{ 
    			bool exceeds <- false;
	    		int i <- 0;
	    		loop while: (exceeds = false) and (i < length_powerlist)
	    		{
	    			if (time_step < 1439)
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
    	if (debug = 1)
		{
	    	write("Powerline: " + my_index + " exceeded combinations: " + exceeded_combinations);
	    	write("Powerline: " + my_index + " in competence combinations: " + combinations_power_sum_tick);
    	}
    }
    
    action get_best_combination
    {
    	combinations_bids_sum <- [];
    	int length_bidlist <- length(combinations_bids_sum_tick);
    	loop comb from: 0 to: length_bidlist-1
    	{
    		add sum(list<float>(combinations_bids_sum_tick[comb])) to: combinations_bids_sum;
    	}
    	
    	float better_combination <- max(combinations_bids_sum);
    	better_combination_index <- combinations_bids_sum last_index_of better_combination;
    	
    	if (debug = 1)
		{
			write("Powerline: " + my_index + " combinations_bids_sum: " + combinations_bids_sum);
    		write("Powerline: " + my_index + " better_combination_index: " + better_combination_index + " better_combination: " + better_combination );
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
    int max_production <- 225; //225KW
    int base_production <- 5; //5KW
    float current_production <- 50.0; //20KW
    list<float> available_nonsmart_power_per_tick;
    list<float> generated_smart_power_per_tick;
    list<float> sold_smart_power_per_tick;
    list<list> combinations_power_sum_tick;
	list<list> combinations_bids_sum_tick;
	list<float> combinations_bids_sum;
	list<list> all_combinations;
	int better_combination_index;
    float max_smart_capacity <- (rnd(5)/100) + 0.15; //between 15 and 20%
       
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
    	
    	loop i from: 0 to: 1439{
			float smart_capacity <- current_production * max_smart_capacity;
			add current_production - smart_capacity to: available_nonsmart_power_per_tick;
			add smart_capacity to: generated_smart_power_per_tick; 
			add 0 to: sold_smart_power_per_tick;
		}
    }
    
    action recalculate_available_power{
    	loop i from: (time_step + 1) to: 1439{
			float smart_capacity <- current_production * max_smart_capacity;
			available_nonsmart_power_per_tick[i] <- current_production - smart_capacity;
			generated_smart_power_per_tick[i] <- smart_capacity;
		}
    }
    
    //step production function
    action production_function_step{
    	float step_value <- 5.0; 
    	bool increase_step <- false;
    	bool decrease_step <- false;
    	float price_factor <- 2.0; //this value is used to mutiply or divide the base_price depending on production increase or decrease

    	if (demand > current_production)
	    {
	     	current_production <- current_production + step_value;
	     	increase_step <- true;
	     	do recalculate_available_power;
	    }
	    else if (demand < ( current_production - step_value ))// - soldpower[time_step+1])) //menos lo que vendi para el tick siguiente
	    {
	    	current_production <- current_production - step_value;
	    	decrease_step <- true;
	    	do recalculate_available_power;
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
    	if (debug = 1)
		{
			write("max_smart_capacity: " + max_smart_capacity);
			write("generator: " + my_index + " demand: " + demand);
		}
		
		do combinatorial_auction;
    }
    
    reflex base_price{
    /*
     * 1 - Considerar ultima cantidad producida y demandada, si esta muy cerca de los limites, aumentar o disminuir produccion
     * 2 - Si la prod aumenta el precio base aumenta, si disminuye, disminuye
     * 3 - ??? si la energia disponible no se ha asignado por completo, bajar el precio y recibir nuevas ofertas
     */
     	power_excess <- current_production - demand;
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
		list<int> elements <- list<int>(my_lines);
		int num_elements <- length(elements);
		loop i from:1 to: num_elements{
			do recursive_combinations(i, elements, combination, my_index, 3);	
		}
		if (debug = 1)
		{
			write("Generator: " + my_index + " elements: " + elements);
			write("Generator: " + my_index + " combinations: " + all_combinations);
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
				//write("Powerline: " + pl + " pl_better_combination_index: " + pl_better_combination_index);
				//write("Powerline: " + pl + " elem better comb: " + powerline(pl).combinations_power_sum_tick[pl_better_combination_index]);
		  		
		  		if (num_rows > 0)
		  		{
		  			loop i from: 0 to: num_rows - 1 {
			  			//write("Generator: " + my_index  + " comb: " + comb + " Powerline: " + pl + " row: " + i + " max_index_container: " + max_index_container);
			  			if (max_index_container < i)
			  			{
			  				//write("Generator: " + my_index  + " comb: " + comb + " Powerline: " + pl + " row: " + i + " "+ powerline(pl).combinations_power_sum_tick[pl_better_combination_index][i]);
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
		
		if (debug = 1)
		{
			write("Generator: " + my_index + " combinations_power_sum_tick: " + combinations_power_sum_tick);
			write("Generator: " + my_index + " combinations_bids_sum_tick: " + combinations_bids_sum_tick);
    	}
    }
    
    action remove_exceeded_combinations
    {
    	list<int> exceeded_combinations <- [];
    	int length_combinations <- length(all_combinations);
    	loop comb from: 0 to: length_combinations - 1
    	{
    		int length_powerlist <- length(combinations_power_sum_tick[comb]);
    		if (length_powerlist > 0)
    		{ 
    			bool exceeds <- false;
	    		int i <- 0;
	    		loop while: (exceeds = false) and (i < length_powerlist)
	    		{
	    			if (time_step < 1439)
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
    	
    	if (debug = 1)
		{
	    	write("Generator: " + my_index + " exceeded combinations: " + exceeded_combinations);
	    	write("Generator: " + my_index + " in competence combinations: " + combinations_power_sum_tick);
    	}
    }
    
    action get_best_combination
    {
    	combinations_bids_sum <- [];
    	int length_bidlist <- length(combinations_bids_sum_tick);
    	loop comb from: 0 to: length_bidlist-1
    	{
    		add sum(list<float>(combinations_bids_sum_tick[comb])) to: combinations_bids_sum;
    	}
    	
    	float better_combination <- max(combinations_bids_sum);
    	better_combination_index <- combinations_bids_sum last_index_of better_combination;
    	
    	if (debug = 1)
		{
			write("Generator: " + my_index + " combinations_bids_sum: " + combinations_bids_sum);
    		write("Generator: " + my_index + " better_combination_index: " + better_combination_index + " better_combination: " + better_combination );
    	}
    }
    
    action assign_power
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
    //parameter "Number of houses: " var: num_houses min: 4 max: 100 category: "House" ;
    parameter "Debug?: " var: debug min: 0 max: 1 category: "General configuration" ;
    
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
  						data "smart demand" value: totalenergy_smart color: rgb('green') ;
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
    		display powerexcess_chart_display {
					chart "Power excess" type: series {
						data "power excess" value: power_excess color: rgb('red') ;
					}
    		}
    		
	}
}