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
	float totalenergy <- 0.0;
	
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
    
    // MySQL connection parameter
	map<string, string>  MySQL <- [
    'host'::'localhost',
    'dbtype'::'MySQL',
    'database'::'sgtest', // it may be a null string
    'port'::'3306',
    'user'::'smartgrid',
    'passwd'::'smartgrid'];
    
    init {
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
	  		}
	  	}
	  	
	  	loop pl_2 over: powerline {
	  		ask pl_2{
	  			do get_my_transformers;	
	  		}
	  		loop tr over: (pl_2.my_transformers) {
	  			create edge_agent with: [shape::link({pl_2.my_x, pl_2.my_y}::{tr.my_x, tr.my_y})] returns: edges_created;
	  			add edge:(pl_2::tr)::first(edges_created) to: general_graph;
	  		}
	  	} 
	  	
	  	loop tr_2 over: transformer{
	  		ask tr_2{
	  			do get_my_houses;	
	  		}
	  		loop hs over: (tr_2.my_houses) {
	  			create edge_agent with: [shape::link({tr_2.my_x, tr_2.my_y}::{hs.my_x, hs.my_y})] returns: edges_created;
	  			add edge:(tr_2::hs)::first(edges_created) to: general_graph;
	  		}
	  	} 
	  	//write general_graph;
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
}

//House
species house parent: agentDB {
    int house_size <- 4;
    int time <- 0;
    int my_index <- house index_of self;
    int num_appliances <- rnd(5) + 2;
    int houseprofile <- rnd(9) + 1;
    list<appliance> my_appliances <- [];
    file my_icon <- file("../images/House.gif");
    float demand <- 0.0;
    
    float my_x <- get_coordinate_x(radius_house, my_index, degree_house);
    float my_y <- get_coordinate_y(radius_house, my_index, degree_house);
    
    float degree_appliance <- (360 / num_appliances);
            
    aspect base {
		draw sphere(house_size) color: rgb('blue') at: {my_x , my_y, 0 } ;
	}
	
	aspect icon {
        draw my_icon size: house_size at: {my_x , my_y, 0 } ;
        draw string(demand) size: 3 color: rgb("black") at: {my_x , my_y, 0 };
    }
	
	action get_my_appliances{
		loop i from: 1 to: num_appliances{
			create appliance number: 1 returns: appliance_created;
	  		add appliance(appliance_created) to: my_appliances;
	  	}
	}
	
	reflex getdemand{
			list<list> t <- list<list> (self select(select:"SELECT h" + houseprofile + " FROM caso0 where timestep = " + time + ";"));
		 	//float t <- float (self select(select:"SELECT h" + houseprofile + " FROM caso0 where timestep = " + time + ";"));
		 	demand <- float (t[2][0][0]);
		 	
		 	if(time = 1439)
		 	{
		 		time <- 0;
		 	}
		 	else
		 	{
		 		time <- time + 1;
		 	}
		 	
			totalenergy <- 0.0;
		 	totalenergy <- totalenergy + demand;
	}
	
	init{
		do get_my_appliances;
		do connect (params: MySQL);
	}
	
//Appliances
	species appliance parent: agentDB {
		int appliance_size <- 2;
		int my_appliance_index <- appliance index_of self;
		float my_appliance_x <- house(host).my_x + (radius_appliance *(cos(my_appliance_index*degree_appliance))); 
		float my_appliance_y <- house(host).my_y + (radius_appliance *(sin(my_appliance_index*degree_appliance)));
		file my_icon <- file("../images/Appliance.gif") ;
		
		int policy <- rnd(3) + 1;
		//int type <- rnd_choice(["Refrigerator", "Washermachine", "Dishwasher"]); 
		int demand_pattern <- 1; //todo: list per slot of time the amount of power it will consume
		
		aspect appliance_base {
			draw sphere(appliance_size) color: rgb('purple') at:{my_appliance_x, my_appliance_y, 0};
		}
		
		aspect appliance_icon {
        draw my_icon size: appliance_size at:{my_appliance_x, my_appliance_y, 0};
    	}
	}
	
}

//Transformers
species transformer parent: agentDB {
    int transformer_size <- 6;
    int my_index <- transformer index_of self;
    list<house> my_houses <- [];
    file my_icon <- file("../images/Transformer.gif") ;
    
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
}

//Power lines
species powerline parent: agentDB {
    int lines_size <- 10;
    int my_index <- powerline index_of self;
	list<transformer> my_transformers <- [];
    file my_icon <- file("../images/PowerLines.gif") ;
    
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
}

//Generator
species generator parent: agentDB {
	int generator_size <- 10;
	list<powerline> my_lines update:(list (species(powerline)));
	float my_x <- (grid_width/4);
    float my_y <- (grid_height/4);
    file my_icon <- file("../images/PowerPlant.gif") ;
       
	aspect base {
		draw sphere(generator_size) color: rgb('red') at: {my_x , my_y , 0 } ;			
	}
	
	aspect icon {
        draw my_icon size: generator_size at: {my_x , my_y, 0 } ;
    }
    
    action checkCon{
    	if (self testConnection(params:MySQL)){
        write "Connection is OK" ;
		}else{
        write "Connection is false" ;
		}
    }
    
	//Connection test
	init {
		do checkCon; 
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
						species appliance aspect: appliance_icon;
					}
                    species transformer aspect: icon;
                    species powerline aspect: icon;
                    species generator aspect: icon;
                    species edge_agent aspect: base;
            }
            display chart_display {
  					chart "Total demand" type: series {
  					data "demand" value: totalenergy color: rgb('red') ;
					}
    		}
	}
}