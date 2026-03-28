-- 41 real Bengaluru traffic signals
INSERT INTO traffic_signals
  (intersection_name, latitude, longitude, green_duration, yellow_duration,
   red_duration, cycle_time, offset_seconds, road_name, city, zone, atms_id)
VALUES
('Silk Board Junction',    12.9168,77.6234,55,5,70,130,0,  'Hosur Road',        'Bengaluru','South', 'KA-S-001'),
('Forum Mall Signal',      12.9340,77.6095,45,5,60,110,15, 'Hosur Road',        'Bengaluru','South', 'KA-S-002'),
('Madiwala Check Post',    12.9263,77.6205,40,5,55,100,30, 'Hosur Road',        'Bengaluru','South', 'KA-S-003'),
('Koramangala 80ft Road',  12.9352,77.6245,45,5,60,110,10, '80 Feet Road',      'Bengaluru','South', 'KA-S-004'),
('BTM Layout Signal',      12.9165,77.6101,40,5,55,100,25, 'BTM Layout Road',   'Bengaluru','South', 'KA-S-005'),
('Jayanagar 4th Block',    12.9284,77.5837,45,5,55,105,5,  'Jayanagar Road',    'Bengaluru','South', 'KA-S-006'),
('JP Nagar Signal',        12.9063,77.5857,50,5,65,120,30, 'JP Nagar Ring Road','Bengaluru','South', 'KA-S-007'),
('Electronic City Toll',   12.8399,77.6770,60,5,75,140,35, 'Hosur Road NH-44',  'Bengaluru','South', 'KA-S-008'),
('Lal Bagh Gate West',     12.9502,77.5835,40,5,50,95,20,  'Lal Bagh Road',     'Bengaluru','South', 'KA-S-009'),
('MG Road Signal',         12.9756,77.6099,55,5,50,110,10, 'MG Road',           'Bengaluru','Central','KA-C-001'),
('Richmond Circle',        12.9629,77.5991,50,5,60,115,40, 'Richmond Road',     'Bengaluru','Central','KA-C-002'),
('Shivajinagar Bus Stop',  12.9900,77.6000,40,5,45,90,5,   'Queens Road',       'Bengaluru','Central','KA-C-003'),
('Ulsoor Lake Signal',     12.9827,77.6221,40,5,50,95,0,   'Ulsoor Road',       'Bengaluru','Central','KA-C-004'),
('Brigade Road Signal',    12.9719,77.6076,50,5,55,110,15, 'Brigade Road',      'Bengaluru','Central','KA-C-005'),
('Trinity Circle',         12.9744,77.6155,45,5,60,110,0,  'Old Airport Road',  'Bengaluru','Central','KA-C-006'),
('Domlur Junction',        12.9605,77.6381,50,5,60,115,25, 'Domlur Layout',     'Bengaluru','Central','KA-C-007'),
('Marathahalli Bridge',    12.9591,77.6972,50,5,55,110,15, 'Outer Ring Road',   'Bengaluru','East',  'KA-E-001'),
('Whitefield Main Signal', 12.9698,77.7500,50,5,65,120,25, 'Whitefield Road',   'Bengaluru','East',  'KA-E-002'),
('Indiranagar 100ft Road', 12.9784,77.6408,40,5,45,90,5,   '100 Feet Road',     'Bengaluru','East',  'KA-E-003'),
('Bellandur Signal',       12.9263,77.6769,45,5,55,105,15, 'Sarjapur Road',     'Bengaluru','East',  'KA-E-004'),
('Old Airport Road Signal',12.9716,77.6490,45,5,55,105,35, 'Old Airport Road',  'Bengaluru','East',  'KA-E-005'),
('KR Puram Signal',        13.0069,77.6946,55,5,65,125,30, 'Old Madras Road',   'Bengaluru','East',  'KA-E-006'),
('Hebbal Flyover',         13.0356,77.5970,60,5,55,120,20, 'NH-44',             'Bengaluru','North', 'KA-N-001'),
('Mekhri Circle',          13.0102,77.5829,55,5,60,120,35, 'Ballari Road',      'Bengaluru','North', 'KA-N-002'),
('Sadashivanagar Signal',  13.0082,77.5748,45,5,55,105,15, 'Palace Road',       'Bengaluru','North', 'KA-N-003'),
('Thanisandra Junction',   13.0594,77.6354,50,5,65,120,20, 'Thanisandra Road',  'Bengaluru','North', 'KA-N-004'),
('Yeshwantpur Circle',     13.0232,77.5510,55,5,60,120,45, 'Tumkur Road',       'Bengaluru','West',  'KA-W-001'),
('Rajajinagar Signal',     12.9980,77.5530,45,5,50,100,15, 'Rajajinagar Main',  'Bengaluru','West',  'KA-W-002'),
('Magadi Road Jn',         12.9698,77.5396,45,5,55,105,25, 'Magadi Road',       'Bengaluru','West',  'KA-W-003'),
('Peenya Junction',        13.0300,77.5190,55,5,65,125,40, 'Tumkur Road',       'Bengaluru','West',  'KA-W-004'),
('Tin Factory Junction',   12.9943,77.6617,55,5,65,125,0,  'Outer Ring Road',   'Bengaluru','East',  'KA-O-001'),
('Bagmane Tech Park',      12.9810,77.6570,40,5,50,95,10,  'CV Raman Nagar',    'Bengaluru','East',  'KA-E-007'),
('Sarjapur Road Jn',       12.9107,77.6838,45,5,65,115,40, 'Sarjapur Road',     'Bengaluru','East',  'KA-E-008'),
('Bommanahalli Signal',    12.8970,77.6301,45,5,60,110,20, 'Hosur Road',        'Bengaluru','South', 'KA-S-010'),
('HBR Layout Junction',    13.0212,77.6391,45,5,55,105,0,  'HBR Layout Road',   'Bengaluru','North', 'KA-N-005'),
('Residency Road Jn',      12.9688,77.6024,45,5,55,105,25, 'Residency Road',    'Bengaluru','Central','KA-C-008'),
('Kundalahalli Junction',  12.9861,77.7101,50,5,60,115,20, 'ORR',               'Bengaluru','East',  'KA-E-009'),
('Chord Road Junction',    12.9895,77.5410,45,5,55,105,30, 'Chord Road',        'Bengaluru','West',  'KA-W-005'),
('Vijayanagar Signal',     12.9701,77.5279,40,5,50,95,10,  'Vijayanagar Road',  'Bengaluru','West',  'KA-W-006'),
('KR Puram ORR',           13.0081,77.6868,50,5,65,120,15, 'Outer Ring Road',   'Bengaluru','East',  'KA-O-002'),
('Intermediate Ring Road', 12.9680,77.6282,45,5,55,105,10, 'IRR',               'Bengaluru','Central','KA-C-009')
ON CONFLICT (atms_id) DO NOTHING;

UPDATE traffic_signals
SET cycle_time = green_duration + yellow_duration + red_duration
WHERE cycle_time IS NULL OR cycle_time = 110;
