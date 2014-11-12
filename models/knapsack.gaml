/**
 *  knapsack
 *  Author: Priscila
 *  Description: 
 */

model knapsack

/* Insert your model definition here */

global {
        int nb_preys_init <- 1;
        list<int> pending_smart_appliances <- [0,1];
        list<float> appliances_bids_sum <- [1.426, 1.059];
        list<float> appliances_energy_sum <- [0.984, 1.433];
        list<int> in_budget_appliances;
        list<bool> takeNotake;
        int length_pending_smart_appliances;
        
        
        init {
			create prey number: nb_preys_init ;
            length_pending_smart_appliances <- length(pending_smart_appliances);
            loop i from: 0 to: length_pending_smart_appliances - 1{
            	add false to: takeNotake;
            }
            
            write("RESULT - knapsack result: " + knapsack(3, length_pending_smart_appliances)); 
            //write("RESULT - knapsack result: " + knapsack2(1.5, 0));
            //write("in_budget_appliances: " + in_budget_appliances);
            write("takeNotake: " + takeNotake);
        }
        
        float knapsack(float available_budget, int n){
        	write("knapsack(available_budget = " + available_budget +", n = "+ n +")");
			if (n <= 0 or available_budget <= 0 )
			{
				write("  n <= 0 or available_budget <= 0");
				return 0.0;
			}
			
			if (appliances_bids_sum[n-1] > available_budget)
			{
				write("  appliances_bids_sum[n-1] > available_budget");
				return knapsack(available_budget, n-1);
			}
			else
			{
				write("  else appliances_bids_sum[n-1] > available_budget");
				
				/*list<float> recursive_options <- [];
				add (appliances_energy_sum[n-1] + knapsack( (available_budget - appliances_bids_sum[n-1]), n-1 )) to: recursive_options;
				add (knapsack( available_budget , n-1 )) to: recursive_options;
				
				write("    recursive_options: " + recursive_options);
				if (recursive_options[0] > recursive_options[1] )
				{
					add	pending_smart_appliances[n-1] to: in_budget_appliances;
				}
				
				return max(recursive_options);
				*/
				float take <- appliances_energy_sum[n-1] + knapsack( (available_budget - appliances_bids_sum[n-1]), n-1 );
				float dont_take <- knapsack( available_budget , n-1 );
				
				write("    take: " + take + " dont_take: " + dont_take);
				
				if (take >= dont_take)
				{
					takeNotake[n-1] <- true;
					if (n-2 >= 0 )
					{
						takeNotake[n-2] <- false;
					}
					return take;
				}
				else
				{
					takeNotake[n-1] <- false;
					if (n-2 >= 0 )
					{
						takeNotake[n-2] <- true;
					}
					return dont_take;
				}
				
				
				
			}
		}
		
		bool knapsack2(float available_budget, int index){
			return true;
			
			if(index = length_pending_smart_appliances){
				return false;
			}
			
			if (appliances_bids_sum[index] < available_budget)
			{
				bool result <- knapsack2(available_budget - appliances_bids_sum[index], index+1);
				if (result = false)
				{
					return knapsack2(available_budget, index+1);
				}
				else
				{
					add pending_smart_appliances[index] to: in_budget_appliances;
					return true;
				}
			}
			
			else if (appliances_bids_sum[index] > available_budget)
			{
				return knapsack2(available_budget, index+1);	
			}
			
			else
			{
				add pending_smart_appliances[index] to: in_budget_appliances;
				return true;
			}
		}
}

species prey {
        float size <- 1.0 ;
        rgb color <- #blue;
                
        aspect base {
                draw circle(size) color: color ;
        }
} 

experiment prey_predator type: gui {
        parameter "Initial number of preys: " var: nb_preys_init min: 1 max: 1000 category: "Prey" ;
        output {
                display main_display {
                        species prey aspect: base ;
                }
        }
}

