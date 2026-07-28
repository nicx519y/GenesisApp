import 'origin_debug_content_models.dart';

const originDebugContentTemplates = <OriginDebugContentTemplate>[
  OriginDebugContentTemplate(
    name: 'Neon Harbor',
    worldView:
        'A storm-locked harbor trades memories as currency while its lighthouse begins sending messages from tomorrow.',
    worldLogic:
        'Every exchanged memory changes one relationship. The lighthouse predicts only events someone still has time to prevent.',
    firstCharacterName: 'Mira Vale',
    firstCharacterIdentity: 'Lighthouse keeper',
    firstCharacterBio:
        'Mira records every impossible transmission and trusts no official archive.',
    firstCharacterGoal:
        'Identify the sender before the next storm erases the harbor.',
    secondCharacterName: 'Ivo Renn',
    secondCharacterIdentity: 'Memory broker',
    secondCharacterBio:
        'Ivo can price any recollection but secretly keeps the ones nobody buys.',
    secondCharacterGoal:
        'Recover a missing day that links him to the lighthouse.',
    regions: <OriginDebugRegionTemplate>[
      OriginDebugRegionTemplate(
        name: 'Glass Coast',
        districts: <OriginDebugDistrictTemplate>[
          OriginDebugDistrictTemplate(
            name: 'Lantern Ward',
            locations: <OriginDebugLocationTemplate>[
              OriginDebugLocationTemplate(
                name: 'Signal Pier',
                description:
                    'A rain-soaked pier crowded with antennae and memory traders.',
                imageKeywords: 'harbor,architecture',
              ),
              OriginDebugLocationTemplate(
                name: 'Midnight Market',
                description:
                    'A covered bazaar where every stall opens only after sunset.',
                imageKeywords: 'market,building',
              ),
            ],
          ),
          OriginDebugDistrictTemplate(
            name: 'Breakwater District',
            locations: <OriginDebugLocationTemplate>[
              OriginDebugLocationTemplate(
                name: 'Storm Observatory',
                description:
                    'A cliffside station that measures lightning before it forms.',
                imageKeywords: 'observatory,landscape',
              ),
              OriginDebugLocationTemplate(
                name: 'Last Ferry Terminal',
                description:
                    'An abandoned terminal whose departure board still changes.',
                imageKeywords: 'terminal,architecture',
              ),
            ],
          ),
        ],
      ),
      OriginDebugRegionTemplate(
        name: 'Old Tide City',
        districts: <OriginDebugDistrictTemplate>[
          OriginDebugDistrictTemplate(
            name: 'Archive Quarter',
            locations: <OriginDebugLocationTemplate>[
              OriginDebugLocationTemplate(
                name: 'Tide Archive',
                description:
                    'A stone library where shelves rise and fall with the sea.',
                imageKeywords: 'library,interior',
              ),
              OriginDebugLocationTemplate(
                name: 'Flooded Courtyard',
                description:
                    'A quiet plaza reflecting towers that no longer exist.',
                imageKeywords: 'courtyard,architecture',
              ),
            ],
          ),
        ],
      ),
    ],
    openingNarration:
        'At dawn, the lighthouse flashes a warning in a code not invented yet.',
    openingDialogue: 'You arrived exactly when the message said you would.',
    storyEvents: <String>[
      'A sealed memory is auctioned under the player’s name.',
      'The harbor clock skips forward by twenty-four hours.',
      'A ferry returns carrying passengers who vanished ten years ago.',
    ],
  ),
  OriginDebugContentTemplate(
    name: 'Clockwork Garden',
    worldView:
        'A mechanical garden keeps the last city alive, but its seasons have started changing out of order.',
    worldLogic:
        'Each repaired machine restores one district and disables another. Only living promises can power the oldest engines.',
    firstCharacterName: 'Sera Moss',
    firstCharacterIdentity: 'Season mechanic',
    firstCharacterBio:
        'Sera repairs weather engines by listening to the rhythm of their gears.',
    firstCharacterGoal:
        'Restore spring before the city’s final seed bank freezes.',
    secondCharacterName: 'Tarin Quill',
    secondCharacterIdentity: 'Runaway archivist',
    secondCharacterBio:
        'Tarin stole a maintenance manual that rewrites itself every night.',
    secondCharacterGoal: 'Find out why the garden has erased its first winter.',
    regions: <OriginDebugRegionTemplate>[
      OriginDebugRegionTemplate(
        name: 'Verdant Engine',
        districts: <OriginDebugDistrictTemplate>[
          OriginDebugDistrictTemplate(
            name: 'Spring Assembly',
            locations: <OriginDebugLocationTemplate>[
              OriginDebugLocationTemplate(
                name: 'Brass Orchard',
                description:
                    'Metal trees grow glass fruit filled with fragments of weather.',
                imageKeywords: 'garden,landscape',
              ),
              OriginDebugLocationTemplate(
                name: 'Keeper Workshop',
                description:
                    'A cramped workshop built inside the garden’s central gear.',
                imageKeywords: 'workshop,interior',
              ),
            ],
          ),
          OriginDebugDistrictTemplate(
            name: 'Winter Foundry',
            locations: <OriginDebugLocationTemplate>[
              OriginDebugLocationTemplate(
                name: 'Frost Conservatory',
                description:
                    'A glass hall where snowflakes are catalogued by sound.',
                imageKeywords: 'greenhouse,architecture',
              ),
              OriginDebugLocationTemplate(
                name: 'Boiler Chapel',
                description:
                    'An iron sanctuary built around the city’s oldest furnace.',
                imageKeywords: 'industrial,interior',
              ),
            ],
          ),
          OriginDebugDistrictTemplate(
            name: 'Summer Circuit',
            locations: <OriginDebugLocationTemplate>[
              OriginDebugLocationTemplate(
                name: 'Sun Dial Plaza',
                description:
                    'A bright plaza whose shadows vote on the next season.',
                imageKeywords: 'plaza,architecture',
              ),
              OriginDebugLocationTemplate(
                name: 'Rain Engine',
                description:
                    'A tower of copper pipes suspended above a reflecting pool.',
                imageKeywords: 'tower,landscape',
              ),
            ],
          ),
        ],
      ),
    ],
    openingNarration:
        'Snow falls upward through the Brass Orchard as every alarm begins to sing.',
    openingDialogue: 'Do not touch the fruit—the garden is remembering us.',
    storyEvents: <String>[
      'A mechanical tree produces a key bearing tomorrow’s date.',
      'The central gear stops, revealing a hidden staircase.',
      'Summer and winter arrive at the same time in neighboring districts.',
    ],
  ),
  OriginDebugContentTemplate(
    name: 'Lunar Bazaar',
    worldView:
        'A traveling night market lands on a different moon each week and sells bargains that alter local history.',
    worldLogic:
        'Every bargain must be repaid before departure. Unpaid debts become permanent laws on the next moon.',
    firstCharacterName: 'Nia Sol',
    firstCharacterIdentity: 'Bazaar pathfinder',
    firstCharacterBio:
        'Nia charts safe routes between moons using songs inherited from her family.',
    firstCharacterGoal:
        'Prevent the bazaar from landing on a moon erased from every chart.',
    secondCharacterName: 'Orin Pax',
    secondCharacterIdentity: 'Debt collector',
    secondCharacterBio:
        'Orin enforces bargains precisely, even when he believes they are unjust.',
    secondCharacterGoal:
        'Break one impossible contract without destroying the bazaar.',
    regions: <OriginDebugRegionTemplate>[
      OriginDebugRegionTemplate(
        name: 'Silver Caravan',
        districts: <OriginDebugDistrictTemplate>[
          OriginDebugDistrictTemplate(
            name: 'Comet Arcade',
            locations: <OriginDebugLocationTemplate>[
              OriginDebugLocationTemplate(
                name: 'Gravity Tea House',
                description:
                    'A floating tea house where cups orbit their guests.',
                imageKeywords: 'teahouse,interior',
              ),
              OriginDebugLocationTemplate(
                name: 'Echo Auction',
                description:
                    'A silent hall where bidders trade gestures instead of coins.',
                imageKeywords: 'auction,building',
              ),
            ],
          ),
          OriginDebugDistrictTemplate(
            name: 'Meteor Promenade',
            locations: <OriginDebugLocationTemplate>[
              OriginDebugLocationTemplate(
                name: 'Starlight Kitchen',
                description:
                    'A rooftop kitchen serving dishes that glow after midnight.',
                imageKeywords: 'rooftop,city',
              ),
              OriginDebugLocationTemplate(
                name: 'Mapmaker Tent',
                description:
                    'A silk pavilion filled with charts of impossible orbits.',
                imageKeywords: 'tent,landscape',
              ),
            ],
          ),
        ],
      ),
      OriginDebugRegionTemplate(
        name: 'Eclipse Annex',
        districts: <OriginDebugDistrictTemplate>[
          OriginDebugDistrictTemplate(
            name: 'Shadow Exchange',
            locations: <OriginDebugLocationTemplate>[
              OriginDebugLocationTemplate(
                name: 'Identity Vault',
                description:
                    'A black stone bank holding names in crystal drawers.',
                imageKeywords: 'vault,interior',
              ),
              OriginDebugLocationTemplate(
                name: 'Departure Gate',
                description:
                    'A luminous arch that opens only when every debt is counted.',
                imageKeywords: 'gate,architecture',
              ),
            ],
          ),
        ],
      ),
    ],
    openingNarration:
        'The bazaar lands early, and a second moon appears beneath the floor.',
    openingDialogue:
        'Keep your name close. Tonight, someone is buying identities.',
    storyEvents: <String>[
      'A vendor offers a map showing a city that does not exist yet.',
      'An unpaid bargain turns gravity sideways across the district.',
      'The departure bell rings while half the stalls remain locked.',
    ],
  ),
  OriginDebugContentTemplate(
    name: 'Ember Frontier',
    worldView:
        'Settlements cling to the rim of a sleeping supervolcano while a new railway uncovers cities buried in warm ash.',
    worldLogic:
        'Heat is both currency and law. Opening an ancient chamber redirects pressure toward another settlement.',
    firstCharacterName: 'Kael Rook',
    firstCharacterIdentity: 'Ash railway marshal',
    firstCharacterBio:
        'Kael keeps the frontier trains moving and records every tremor by hand.',
    firstCharacterGoal:
        'Evacuate the rim without surrendering the railway to the mining houses.',
    secondCharacterName: 'Yara Flint',
    secondCharacterIdentity: 'Volcanic cartographer',
    secondCharacterBio:
        'Yara maps tunnels by reading mineral colors in the dark.',
    secondCharacterGoal: 'Reach the buried capital before its furnace wakes.',
    regions: <OriginDebugRegionTemplate>[
      OriginDebugRegionTemplate(
        name: 'Cinder Rim',
        districts: <OriginDebugDistrictTemplate>[
          OriginDebugDistrictTemplate(
            name: 'Railhead Colony',
            locations: <OriginDebugLocationTemplate>[
              OriginDebugLocationTemplate(
                name: 'Ember Station',
                description:
                    'A red steel terminal where every train arrives coated in ash.',
                imageKeywords: 'trainstation,architecture',
              ),
              OriginDebugLocationTemplate(
                name: 'Pressure Office',
                description:
                    'A fortified control room tracking the volcano’s pulse.',
                imageKeywords: 'controlroom,interior',
              ),
            ],
          ),
          OriginDebugDistrictTemplate(
            name: 'Miner Terrace',
            locations: <OriginDebugLocationTemplate>[
              OriginDebugLocationTemplate(
                name: 'Basalt Lift',
                description:
                    'A cargo elevator descending through layers of glowing rock.',
                imageKeywords: 'mine,industrial',
              ),
              OriginDebugLocationTemplate(
                name: 'Cooling Reservoir',
                description:
                    'A blue lake surrounded by black cliffs and steam towers.',
                imageKeywords: 'volcano,landscape',
              ),
            ],
          ),
        ],
      ),
      OriginDebugRegionTemplate(
        name: 'Buried Crown',
        districts: <OriginDebugDistrictTemplate>[
          OriginDebugDistrictTemplate(
            name: 'Ash Palace',
            locations: <OriginDebugLocationTemplate>[
              OriginDebugLocationTemplate(
                name: 'Obsidian Atrium',
                description:
                    'A royal hall preserved beneath translucent volcanic glass.',
                imageKeywords: 'palace,interior',
              ),
              OriginDebugLocationTemplate(
                name: 'Furnace Throne',
                description: 'A circular chamber built above a river of magma.',
                imageKeywords: 'furnace,architecture',
              ),
            ],
          ),
          OriginDebugDistrictTemplate(
            name: 'Deep Archive',
            locations: <OriginDebugLocationTemplate>[
              OriginDebugLocationTemplate(
                name: 'Sealed Map Room',
                description:
                    'Stone tables display tunnels that continue drawing themselves.',
                imageKeywords: 'maproom,interior',
              ),
              OriginDebugLocationTemplate(
                name: 'Vent Cathedral',
                description:
                    'A cavern where geothermal vents sound like a distant choir.',
                imageKeywords: 'cave,landscape',
              ),
            ],
          ),
        ],
      ),
    ],
    openingNarration:
        'The morning train arrives empty, carrying fresh footprints across its roof.',
    openingDialogue:
        'The mountain changed the timetable. We leave before it changes its mind.',
    storyEvents: <String>[
      'A buried signal begins directing trains toward a closed tunnel.',
      'The cooling reservoir drops ten meters overnight.',
      'An ash-preserved citizen wakes inside the palace.',
    ],
  ),
  OriginDebugContentTemplate(
    name: 'Skyrail Republic',
    worldView:
        'A republic of floating districts depends on rail lines suspended between clouds, and one entire route has begun arriving in the wrong year.',
    worldLogic:
        'Each district controls one section of track. Changing a route shifts political power and alters local time.',
    firstCharacterName: 'Ari Venn',
    firstCharacterIdentity: 'Skyrail conductor',
    firstCharacterBio:
        'Ari has memorized every legal route and several that officially never existed.',
    firstCharacterGoal:
        'Bring the lost route home without starting a district war.',
    secondCharacterName: 'Juno Kite',
    secondCharacterIdentity: 'Cloud engineer',
    secondCharacterBio:
        'Juno repairs bridges from a glider and distrusts automated navigation.',
    secondCharacterGoal:
        'Prove the time failures originate inside the republic’s central station.',
    regions: <OriginDebugRegionTemplate>[
      OriginDebugRegionTemplate(
        name: 'High Capital',
        districts: <OriginDebugDistrictTemplate>[
          OriginDebugDistrictTemplate(
            name: 'Central Junction',
            locations: <OriginDebugLocationTemplate>[
              OriginDebugLocationTemplate(
                name: 'Parliament Terminal',
                description:
                    'A monumental station where platforms double as council chambers.',
                imageKeywords: 'station,architecture',
              ),
              OriginDebugLocationTemplate(
                name: 'Clock Dispatch',
                description:
                    'A brass control tower filled with clocks showing different years.',
                imageKeywords: 'clocktower,interior',
              ),
            ],
          ),
          OriginDebugDistrictTemplate(
            name: 'Cloud Gardens',
            locations: <OriginDebugLocationTemplate>[
              OriginDebugLocationTemplate(
                name: 'Suspension Park',
                description:
                    'A public garden hanging beneath a transparent rail bridge.',
                imageKeywords: 'park,city',
              ),
              OriginDebugLocationTemplate(
                name: 'Wind Museum',
                description:
                    'A spiral building preserving storms in glass chambers.',
                imageKeywords: 'museum,architecture',
              ),
            ],
          ),
        ],
      ),
      OriginDebugRegionTemplate(
        name: 'Outer Platforms',
        districts: <OriginDebugDistrictTemplate>[
          OriginDebugDistrictTemplate(
            name: 'Maintenance Belt',
            locations: <OriginDebugLocationTemplate>[
              OriginDebugLocationTemplate(
                name: 'Glider Dock',
                description:
                    'An open platform crowded with repair wings and cable crews.',
                imageKeywords: 'airport,architecture',
              ),
              OriginDebugLocationTemplate(
                name: 'Route Zero',
                description:
                    'A sealed platform where a train can be heard but never seen.',
                imageKeywords: 'railway,building',
              ),
            ],
          ),
        ],
      ),
    ],
    openingNarration:
        'A train marked Route Zero enters the station beneath a sky with two suns.',
    openingDialogue:
        'No one boards until we know which year is waiting inside.',
    storyEvents: <String>[
      'A district votes to detach its section of railway.',
      'Passengers receive tickets printed with their future occupations.',
      'A cloud bridge begins rebuilding itself toward an unknown island.',
    ],
  ),
  OriginDebugContentTemplate(
    name: 'Sunken Library',
    worldView:
        'An underwater library stores the memories of drowned cities, but its oldest wing has started returning books that were never written.',
    worldLogic:
        'Reading a recovered volume temporarily restores its city around the reader. Closing it sends everything back underwater.',
    firstCharacterName: 'Elen Mar',
    firstCharacterIdentity: 'Deep archive diver',
    firstCharacterBio:
        'Elen retrieves books from flooded shelves and annotates what the water changed.',
    firstCharacterGoal:
        'Find the volume containing her lost hometown before the archive seals it.',
    secondCharacterName: 'Bram Osei',
    secondCharacterIdentity: 'Memory conservator',
    secondCharacterBio:
        'Bram repairs damaged recollections while hiding gaps in his own past.',
    secondCharacterGoal:
        'Stop an unwritten book from replacing the library’s real history.',
    regions: <OriginDebugRegionTemplate>[
      OriginDebugRegionTemplate(
        name: 'Abyssal Archive',
        districts: <OriginDebugDistrictTemplate>[
          OriginDebugDistrictTemplate(
            name: 'Reader Dome',
            locations: <OriginDebugLocationTemplate>[
              OriginDebugLocationTemplate(
                name: 'Tidal Reading Room',
                description:
                    'A glass chamber where schools of fish pass between the shelves.',
                imageKeywords: 'aquarium,interior',
              ),
              OriginDebugLocationTemplate(
                name: 'Memory Desk',
                description:
                    'A circular counter covered in waterproof journals and brass keys.',
                imageKeywords: 'library,interior',
              ),
            ],
          ),
          OriginDebugDistrictTemplate(
            name: 'Flooded Stacks',
            locations: <OriginDebugLocationTemplate>[
              OriginDebugLocationTemplate(
                name: 'Blue Corridor',
                description:
                    'A submerged passage lined with books sealed inside glass walls.',
                imageKeywords: 'underwater,architecture',
              ),
              OriginDebugLocationTemplate(
                name: 'Unwritten Vault',
                description:
                    'A pressure door protecting shelves of completely blank volumes.',
                imageKeywords: 'vault,interior',
              ),
            ],
          ),
          OriginDebugDistrictTemplate(
            name: 'Surface Annex',
            locations: <OriginDebugLocationTemplate>[
              OriginDebugLocationTemplate(
                name: 'Diver Lighthouse',
                description:
                    'A white tower guiding archive crews through permanent fog.',
                imageKeywords: 'lighthouse,landscape',
              ),
              OriginDebugLocationTemplate(
                name: 'Recovery Pier',
                description:
                    'A weathered dock where newly found memories are quarantined.',
                imageKeywords: 'pier,landscape',
              ),
            ],
          ),
        ],
      ),
    ],
    openingNarration:
        'A blank book opens by itself, and a dry street appears beyond the glass.',
    openingDialogue: 'If you step into that city, keep one hand on the cover.',
    storyEvents: <String>[
      'A restored city refuses to disappear when its book closes.',
      'The archive receives a volume written in the player’s handwriting.',
      'A breach sends forgotten memories drifting into the reader dome.',
    ],
  ),
  OriginDebugContentTemplate(
    name: 'Aurora Hotel',
    worldView:
        'A hotel at the edge of the polar night hosts guests from abandoned futures, while the aurora records every promise made inside.',
    worldLogic:
        'Guests may stay only until their future becomes possible again. Broken promises appear as new locked rooms.',
    firstCharacterName: 'Lena Frost',
    firstCharacterIdentity: 'Night manager',
    firstCharacterBio:
        'Lena recognizes every guest but cannot remember checking any of them in.',
    firstCharacterGoal: 'Open Room 0 before the longest night ends.',
    secondCharacterName: 'Noah Vesper',
    secondCharacterIdentity: 'Aurora photographer',
    secondCharacterBio:
        'Noah develops photographs that show promises instead of people.',
    secondCharacterGoal:
        'Find the guest whose missing promise is darkening the sky.',
    regions: <OriginDebugRegionTemplate>[
      OriginDebugRegionTemplate(
        name: 'Northern Wing',
        districts: <OriginDebugDistrictTemplate>[
          OriginDebugDistrictTemplate(
            name: 'Grand Lobby',
            locations: <OriginDebugLocationTemplate>[
              OriginDebugLocationTemplate(
                name: 'Aurora Atrium',
                description:
                    'A glass lobby illuminated by ribbons of green polar light.',
                imageKeywords: 'hotel,interior',
              ),
              OriginDebugLocationTemplate(
                name: 'Midnight Reception',
                description:
                    'A dark wood desk with keys for rooms absent from the floor plan.',
                imageKeywords: 'reception,interior',
              ),
            ],
          ),
          OriginDebugDistrictTemplate(
            name: 'Guest Floors',
            locations: <OriginDebugLocationTemplate>[
              OriginDebugLocationTemplate(
                name: 'Room 0',
                description:
                    'A door behind the elevator that appears only during an aurora.',
                imageKeywords: 'hotelroom,interior',
              ),
              OriginDebugLocationTemplate(
                name: 'Future Suite',
                description:
                    'A luxurious room overlooking a city that has not been built.',
                imageKeywords: 'suite,interior',
              ),
            ],
          ),
        ],
      ),
      OriginDebugRegionTemplate(
        name: 'Polar Grounds',
        districts: <OriginDebugDistrictTemplate>[
          OriginDebugDistrictTemplate(
            name: 'Ice Promenade',
            locations: <OriginDebugLocationTemplate>[
              OriginDebugLocationTemplate(
                name: 'Promise Observatory',
                description:
                    'A silver dome that translates aurora patterns into names.',
                imageKeywords: 'observatory,landscape',
              ),
              OriginDebugLocationTemplate(
                name: 'Frozen Station',
                description:
                    'A tiny railway stop where trains arrive without leaving tracks.',
                imageKeywords: 'winter,building',
              ),
            ],
          ),
          OriginDebugDistrictTemplate(
            name: 'Service Tunnels',
            locations: <OriginDebugLocationTemplate>[
              OriginDebugLocationTemplate(
                name: 'Boiler Passage',
                description:
                    'A warm underground corridor marked with guest initials.',
                imageKeywords: 'tunnel,interior',
              ),
              OriginDebugLocationTemplate(
                name: 'Lost Luggage Vault',
                description:
                    'A warehouse of suitcases belonging to futures that vanished.',
                imageKeywords: 'warehouse,interior',
              ),
            ],
          ),
        ],
      ),
    ],
    openingNarration:
        'The hotel bell rings once, although every guest is already asleep.',
    openingDialogue: 'Room 0 has checked in. That has never happened before.',
    storyEvents: <String>[
      'A suitcase arrives containing photographs of tomorrow’s guests.',
      'The aurora displays a promise made in the player’s voice.',
      'Every door on the guest floor opens onto the same snowy road.',
    ],
  ),
  OriginDebugContentTemplate(
    name: 'Desert Observatory',
    worldView:
        'A desert observatory predicts political revolutions by tracking wandering stars, but the latest constellation points beneath the sand.',
    worldLogic:
        'Each verified prediction changes the route of the stars. Digging up the past makes one future impossible.',
    firstCharacterName: 'Samira Dune',
    firstCharacterIdentity: 'Constellation analyst',
    firstCharacterBio:
        'Samira compares ancient sky maps with public unrest across the continent.',
    firstCharacterGoal:
        'Decode the underground constellation before the royal army arrives.',
    secondCharacterName: 'Theo Marr',
    secondCharacterIdentity: 'Desert excavator',
    secondCharacterBio:
        'Theo follows buried stone roads that appear only under starlight.',
    secondCharacterGoal:
        'Find the city beneath the observatory without repeating its collapse.',
    regions: <OriginDebugRegionTemplate>[
      OriginDebugRegionTemplate(
        name: 'Star Dunes',
        districts: <OriginDebugDistrictTemplate>[
          OriginDebugDistrictTemplate(
            name: 'Observatory Ridge',
            locations: <OriginDebugLocationTemplate>[
              OriginDebugLocationTemplate(
                name: 'Revolution Dome',
                description:
                    'A sandstone observatory whose ceiling maps unrest as moving light.',
                imageKeywords: 'observatory,desert',
              ),
              OriginDebugLocationTemplate(
                name: 'Mirror Courtyard',
                description:
                    'An open court of polished plates reflecting unfamiliar stars.',
                imageKeywords: 'courtyard,desert',
              ),
            ],
          ),
          OriginDebugDistrictTemplate(
            name: 'Caravan Camp',
            locations: <OriginDebugLocationTemplate>[
              OriginDebugLocationTemplate(
                name: 'Navigator Tent',
                description:
                    'A canvas command post filled with brass instruments and maps.',
                imageKeywords: 'tent,desert',
              ),
              OriginDebugLocationTemplate(
                name: 'Dry Well',
                description:
                    'A stone well carrying whispers from the buried city.',
                imageKeywords: 'well,landscape',
              ),
            ],
          ),
        ],
      ),
      OriginDebugRegionTemplate(
        name: 'Buried Meridian',
        districts: <OriginDebugDistrictTemplate>[
          OriginDebugDistrictTemplate(
            name: 'Sand City',
            locations: <OriginDebugLocationTemplate>[
              OriginDebugLocationTemplate(
                name: 'Underground Plaza',
                description:
                    'A vast civic square preserved below layers of golden sand.',
                imageKeywords: 'ruins,architecture',
              ),
              OriginDebugLocationTemplate(
                name: 'Star Chamber',
                description:
                    'A circular room whose floor contains a moving night sky.',
                imageKeywords: 'temple,interior',
              ),
            ],
          ),
        ],
      ),
    ],
    openingNarration:
        'At noon, a constellation appears on the observatory floor instead of the sky.',
    openingDialogue:
        'The stars are not predicting a city. They are remembering one.',
    storyEvents: <String>[
      'A buried road rises above the dunes and points toward the capital.',
      'The observatory predicts a revolution led by someone already dead.',
      'A sandstorm reveals the upper floors of the underground city.',
    ],
  ),
];
