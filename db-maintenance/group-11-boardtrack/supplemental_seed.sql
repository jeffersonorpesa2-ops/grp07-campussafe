-- Supplemental realistic seed data for BoardTrack
DO $$
DECLARE
  p_id INT;
  r_id INT;
  t_id INT;
  l_id INT;
  i INT;
  j INT;
BEGIN
  -- Insert 5 more properties (property_id 3..7)
  FOR i IN 3..7 LOOP
    INSERT INTO property (property_name, address)
    VALUES ('Boarding House ' || i, i || ' University Belt Ave, Los Banos, Laguna')
    RETURNING property_id INTO p_id;

    -- Each property has 6 rooms
    FOR j IN 1..6 LOOP
      INSERT INTO room (property_id, room_number, monthly_rate, status)
      VALUES (p_id, 'Unit-' || (i*10 + j), 3000 + (j * 250), 'AVAILABLE')
      RETURNING room_id INTO r_id;

      -- Insert 1 tenant per room
      INSERT INTO tenant (full_name, contact_number, email, valid_id_number)
      VALUES ('Tenant ' || p_id || '-' || j, '09' || lpad((p_id*10000000 + j*100000)::text, 9, '0'), 'tenant' || p_id || '_' || j || '@example.com', 'ID-' || p_id || '-' || j)
      RETURNING tenant_id INTO t_id;

      -- Create lease: 4 active, 2 terminated
      IF j <= 4 THEN
        INSERT INTO lease (tenant_id, room_id, start_date, end_date, monthly_rent, status)
        VALUES (t_id, r_id, '2026-01-01', '2026-12-31', 3000 + (j * 250), 'ACTIVE')
        RETURNING lease_id INTO l_id;

        -- Create 3 payments per active lease
        INSERT INTO payment (lease_id, payment_date, amount, payment_method, status) VALUES
          (l_id, '2026-01-05', 3000 + (j * 250), 'GCASH', 'COMPLETED'),
          (l_id, '2026-02-05', 3000 + (j * 250), 'CASH', 'COMPLETED'),
          (l_id, '2026-03-05', 3000 + (j * 250), 'BANK_TRANSFER', CASE WHEN j = 1 THEN 'PENDING' ELSE 'COMPLETED' END);

        -- Create utility bills per active lease
        INSERT INTO utility_bill (lease_id, billing_period, utility_type, amount, status) VALUES
          (l_id, '2026-01-01', 'ELECTRICITY', 450.00 + (j*20), 'PAID'),
          (l_id, '2026-01-01', 'WATER', 180.00 + (j*10), 'PAID'),
          (l_id, '2026-02-01', 'ELECTRICITY', 475.00 + (j*25), CASE WHEN j % 2 = 0 THEN 'PAID' ELSE 'UNPAID' END),
          (l_id, '2026-02-01', 'INTERNET', 600.00, 'PAID');
      ELSE
        -- Past terminated lease
        INSERT INTO lease (tenant_id, room_id, start_date, end_date, moved_out_on, monthly_rent, status)
        VALUES (t_id, r_id, '2025-01-01', '2025-10-31', '2025-10-31', 2800 + (j * 250), 'TERMINATED')
        RETURNING lease_id INTO l_id;

        INSERT INTO payment (lease_id, payment_date, amount, payment_method, status) VALUES
          (l_id, '2025-02-05', 2800 + (j * 250), 'CASH', 'COMPLETED'),
          (l_id, '2025-03-05', 2800 + (j * 250), 'CASH', 'COMPLETED');

        INSERT INTO utility_bill (lease_id, billing_period, utility_type, amount, status) VALUES
          (l_id, '2025-02-01', 'ELECTRICITY', 350.00, 'PAID');
      END IF;
    END LOOP;
  END LOOP;
END $$;
