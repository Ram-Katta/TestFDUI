create or replace TRIGGER "APPS"."XXMSIPO_LINE_LOCATION_TRIG" 
/* +=====================================================================+
      |       M MMMMM M
      |     M MMMMMMMMM M
      |   M MM MMMMMMM MM M
      |  M MMM MMMMMMM MMM M
      | M MMM   MMMMM   MMM M     Copyright(c) 2011 Motorola Solutions Inc.
      | M MMM MM MMM MM MMM M        Schaumburg, Illinois, USA
      | M MM MMMM M MMMM MM M          All rights reserved.
      | M M MMMMMM MMMMMM M M
      |  M MMMMMMMMMMMMMMM M
      |   M MMMMMMMMMMMMM M
      |     M MMMMMMMMM M
      |       M MMMMM M
      +=======================================================================+
      |
      | System:        GreenField
      |
      | Program Name:  XXMSIPO_LINE_LOCATION_TRIG
      |
      | Program Type:  TRIGGER
      |
      | Description:   This trigger is used to default the Ship-to Location
                        at SHipments level
      |
      | Execution:     Apps
      |
      |
      | Revision History:
      | Revision        Date            Author           Reason/Defect
      |   1.0         22/10/2019          Deloitte       Initial version
      |   1.1         26/06/2020          Deloitte       JIRA#819 Changes 
      |   1.2         11/11/2022          TCS            JIRA#D2P-1800
      |   1.3         25/01/2023          TCS            JIRA#D2P-1785
      |   1.4         12/04/2023          TCS            INC3517582 - To restrict service NP po from Match Option Sync
      |   1.6         12/05/2023          TCS            TO Consider Deliver To
      |   1.7         26/06/2023          TCS            To improve the performance INC3603994
      |   1.8         16/08/2026          TCS            Added Vendor Location Override via XXMSI_VENDOR_LOCATION_LKP 
      +=======================================================================+
      | POPI CLASSIFICATION:
      |  Motorola Internal Use Only [X]
      |  Motorola Confidential Proprietary [ ]
      |  Motorola Registered Secret [ ]
      +===============================================+========================+ */ 
BEFORE UPDATE ON "PO"."PO_LINE_LOCATIONS_ALL#"              -- PO . PO_LINE_LOCATIONS_ALL#
FOR EACH ROW
DECLARE
    lv_facil_code            VARCHAR2(3);
    lv_jdm_exists            VARCHAR2(1);
    lv_po_header_id          NUMBER;
    lv_approved_flag         VARCHAR2(3);
    lv_ship_to_location_id   NUMBER;
    lv_err                   VARCHAR2(2000);
    lv_suffix_code           VARCHAR2(10);
    lv_text                  VARCHAR2(100);
    ln_ds_cnt                NUMBER;
    ln_cc_cnt                NUMBER;
    ln_ccsi_cnt              NUMBER;
    ln_de2ds_cnt             NUMBER;
    ln_ship_to_location_id   NUMBER;
    ln_location_id           NUMBER := 0;
    lv_cc_subinv             VARCHAR2(40);
    lv_ds_po_type            VARCHAR2(30);
    lv_net_location_id       NUMBER := 0;--1.2
    ln_loc_cnt               NUMBER;
  --D2P-1745
    lv_po_num                po_headers_all.segment1%TYPE;
    lv_po_status             po_headers_all.authorization_status%TYPE;
    lv_ss_match_option       ap_supplier_sites_all.match_option%TYPE;
    lv_po_match_option       po_line_locations_all.match_option%TYPE;
    lv_source_code           po_headers_all.interface_source_code%TYPE; -- 1.4
    l_ds_cnt                 NUMBER;
    lv_drop_ship_location_id NUMBER;

    -- NEW VARIABLES FOR VENDOR OVERRIDE (1.8)
    ln_vendor_id             po_headers_all.vendor_id%TYPE;
    ln_override_loc_id       VARCHAR2(240);

BEGIN
    lv_po_header_id := NULL;
    ln_location_id := NULL;
    lv_drop_ship_location_id := NULL;
    lv_ship_to_location_id := :old.ship_to_location_id;
    lv_po_header_id := :old.po_header_id;
    ln_location_id := :new.line_location_id;
    ln_ds_cnt := 0;
    l_ds_cnt := 0;
    ln_cc_cnt := 0;
    ln_ccsi_cnt := 0;
    ln_de2ds_cnt := 0;
    lv_ds_po_type := NULL;

  --Begin 1.2
    BEGIN
        SELECT DISTINCT
            hla.location_id
        INTO lv_net_location_id
        FROM
            oe_order_lines_all         oola,
            oe_order_headers_all       ooha,
            fnd_lookup_values_vl       flvl,
            po_lines_all               pola,
            po_requisition_headers_all prh,
            po_requisition_lines_all   prl,
            po_distributions_all       pda,
            po_req_distributions_all   prd,
            hz_cust_accounts           hca,
            hr_locations_all           hla
        WHERE
                1 = 1
            AND pola.po_header_id = lv_po_header_id
            AND oola.inventory_item_id = pola.item_id
            AND oola.line_category_code = 'ORDER'
            AND flvl.lookup_type = 'MSI_SHIP_TO_LOCATION'
            AND oola.booked_flag = 'Y'
            AND nvl(oola.cancelled_flag, 'N') = 'N'
            AND oola.header_id = ooha.header_id
            AND ooha.sold_to_org_id = hca.cust_account_id
            AND flvl.enabled_flag = 'Y'
            AND flvl.description = hca.account_number
            AND flvl.lookup_code = ooha.shipping_method_code
            AND flvl.meaning = hla.location_code
            AND COALESCE(TO_NUMBER(REGEXP_SUBSTR(PRL.ATTRIBUTE1,'^\d+')), 0) = OOLA.LINE_ID 
            AND prh.requisition_header_id = prl.requisition_header_id
            AND prh.type_lookup_code = 'PURCHASE'
            AND prd.requisition_line_id = prl.requisition_line_id
            AND pda.req_distribution_id = prd.distribution_id
            AND pda.destination_organization_id = oola.ship_from_org_id
            AND pda.po_header_id = lv_po_header_id;

    EXCEPTION
        WHEN OTHERS THEN
            lv_net_location_id := NULL;
    END;

    SELECT
        COUNT(1)
    INTO l_ds_cnt
    FROM
        oe_drop_ship_sources oeds
    WHERE
        oeds.po_header_id = lv_po_header_id;


    IF lv_net_location_id IS NOT NULL THEN
        :new.ship_to_location_id := lv_net_location_id;
    ELSIF
        lv_net_location_id IS NULL
        AND l_ds_cnt >= 1   -- 1.6 Starts

    THEN
        BEGIN
            SELECT
               distinct hl_ship.location_id
            INTO lv_drop_ship_location_id
            FROM
                oe_order_headers_all        ooha,
                oe_order_lines_all          oola,
                oe_drop_ship_sources        oeds,
                po_headers_all              poha,
                po_lines_all                pola,
                apps.hz_cust_site_uses_all  hcs_ship,
                apps.hz_cust_acct_sites_all hca_ship,
                apps.hz_party_sites         hps_ship,
                apps.hz_parties             hp_ship,
                apps.hz_locations           hl_ship
            WHERE
                    ooha.header_id = oola.header_id
                AND oeds.header_id = ooha.header_id
                AND oeds.line_id = oola.line_id
                AND oeds.destination_organization_id = oola.ship_from_org_id
                AND oeds.po_header_id = poha.po_header_id
                AND oeds.po_line_id = pola.po_line_id
                AND poha.po_header_id = pola.po_header_id 
                AND poha.po_header_id = lv_po_header_id
                AND hcs_ship.site_use_id = nvl(oola.deliver_to_org_id, oola.ship_to_org_id)
                AND hcs_ship.cust_acct_site_id = hca_ship.cust_acct_site_id
                AND hca_ship.party_site_id = hps_ship.party_site_id
                AND hps_ship.party_id = hp_ship.party_id
                AND hps_ship.location_id = hl_ship.location_id;


        EXCEPTION
            WHEN OTHERS THEN
                lv_drop_ship_location_id := NULL;

        END;

        IF lv_drop_ship_location_id IS NOT NULL THEN
            :new.ship_to_location_id := lv_drop_ship_location_id;
        ELSE
            :new.ship_to_location_id := lv_ship_to_location_id;
        END IF;  -- 1.6 end

    ELSE --End 1.2
        BEGIN
            SELECT
                po_info.po_type
            INTO lv_ds_po_type
            FROM
                (
                    SELECT DISTINCT
                        'BACK2BACK' po_type
                    FROM
                        oe_order_headers_all       ooha,
                        oe_order_lines_all         oola,
                        mtl_system_items_b         msib,
                        po_headers_all             poha,
                        po_lines_all               pola,
                        po_requisition_headers_all prh,
                        po_requisition_lines_all   prl,
                        po_distributions_all       pda,
                        po_req_distributions_all   prd,
                        fnd_lookup_values_vl       flvl1,
                        fnd_lookup_values_vl       flvl_item
                    WHERE
                            1 = 1
                        AND ooha.header_id = oola.header_id
                        AND msib.inventory_item_id = oola.inventory_item_id
                        AND msib.organization_id = oola.ship_from_org_id
                        AND flvl_item.meaning IN ( 'Dropship', 'Dropship Intangible' )
                        AND COALESCE(TO_NUMBER(REGEXP_SUBSTR(PRL.ATTRIBUTE1,'^\d+')), 0) = OOLA.LINE_ID 
                        AND prh.requisition_header_id = prl.requisition_header_id
                        AND prh.type_lookup_code = 'PURCHASE'
                        AND prd.requisition_line_id = prl.requisition_line_id
                        AND pda.req_distribution_id = prd.distribution_id
                        AND pda.po_header_id = poha.po_header_id
                        AND pda.po_line_id = pola.po_line_id
                        AND poha.po_header_id = pola.po_header_id
                        AND poha.po_header_id = lv_po_header_id
                        AND pda.line_location_id = ln_location_id
                        AND upper(flvl1.meaning) = upper(flvl_item.meaning)
                        AND flvl1.lookup_type = 'ITEM_TYPE'
                        AND flvl_item.lookup_type = 'XXMSI_CON_DS_ITEM_TYPE_LKP'
                        AND flvl1.enabled_flag = 'Y'
                        AND flvl_item.enabled_flag = 'Y'
                        AND msib.item_type = flvl1.lookup_code
                ) po_info;

        EXCEPTION
            WHEN no_data_found THEN
                lv_ds_po_type := NULL;
            WHEN OTHERS THEN
                lv_ds_po_type := NULL;
        END;

        IF lv_ds_po_type = 'BACK2BACK' THEN
            BEGIN
                SELECT
                    COUNT(1),
                    oola.subinventory
                INTO
                    ln_cc_cnt,
                    lv_cc_subinv
                FROM
                    oe_order_lines_all         oola,
                    oe_order_headers_all       ooha,
                    fnd_lookup_values_vl       flvl,
                    po_lines_all               pola,
                    po_requisition_headers_all prh,
                    po_requisition_lines_all   prl,
                    po_distributions_all       pda,
                    po_req_distributions_all   prd
                WHERE
                        1 = 1
                    AND pola.po_header_id = lv_po_header_id
                    AND oola.inventory_item_id = pola.item_id
                    AND oola.line_category_code = 'ORDER'
                    AND flvl.lookup_type = 'XXMSI_CON_SUBINV_LOC_MAPPING'
                    AND upper(oola.source_type_code) = upper(flvl.description)
                    AND oola.booked_flag = 'Y'
                    AND nvl(oola.cancelled_flag, 'N') = 'N'
                    AND oola.header_id = ooha.header_id
                    AND flvl.enabled_flag = 'Y'
                    AND oola.subinventory = flvl.lookup_code
                    AND COALESCE(TO_NUMBER(REGEXP_SUBSTR(PRL.ATTRIBUTE1,'^\d+')), 0) = OOLA.LINE_ID 
                    AND prh.requisition_header_id = prl.requisition_header_id
                    AND prh.type_lookup_code = 'PURCHASE'
                    AND prd.requisition_line_id = prl.requisition_line_id
                    AND pda.req_distribution_id = prd.distribution_id
                    AND pda.destination_organization_id = oola.ship_from_org_id
                    AND pda.po_header_id = lv_po_header_id
                GROUP BY
                    oola.subinventory;

            EXCEPTION
                WHEN OTHERS THEN
                    lv_err := substr(sqlerrm, 1, 40);
                    xxpo_prefix_no_pkg.xxpo_prefix_err_proc(p_po_hdr_id => :old.po_header_id, p_po_num => :old.po_header_id, p_stats => 'E'
                    , p_err => lv_err, p_run_id => fnd_global.conc_request_id);

            END;

            IF ln_cc_cnt > 0 THEN
                BEGIN
                    SELECT
                        location_id
                    INTO ln_ship_to_location_id                
                    FROM
                        hr_locations         hrl,
                        fnd_lookup_values_vl flvl
                    WHERE
                            hrl.location_code = flvl.meaning
                        AND flvl.lookup_type = 'XXMSI_CON_SUBINV_LOC_MAPPING'
                        AND flvl.lookup_code = lv_cc_subinv;

                EXCEPTION
                    WHEN OTHERS THEN
                        lv_ship_to_location_id := :new.ship_to_location_id;
                END;

                :new.ship_to_location_id := ln_ship_to_location_id;
            ELSE
                :new.ship_to_location_id := lv_ship_to_location_id;
            END IF;

        END IF;

    END IF;--1.2

    -- =======================================================================
    -- START 1.8: VENDOR SPECIFIC LOCATION OVERRIDE (NEW LOOKUP)
    -- =======================================================================
    BEGIN
        -- 1. Fetch Vendor ID from Header
        SELECT vendor_id
          INTO ln_vendor_id
          FROM po_headers_all
         WHERE po_header_id = :old.po_header_id;

        -- 2. Check the new lookup XXMSI_VENDOR_LOCATION_LKP
        -- LOOKUP_CODE = Vendor ID
        -- MEANING = Location ID
        SELECT flvl.meaning 
          INTO ln_override_loc_id
          FROM fnd_lookup_values_vl flvl
         WHERE flvl.lookup_type = 'XXMSI_VENDOR_LOCATION_LKP'
           AND flvl.tag = TO_CHAR(ln_vendor_id)
           AND flvl.enabled_flag = 'Y'
           AND SYSDATE BETWEEN NVL(flvl.start_date_active, SYSDATE) 
                           AND NVL(flvl.end_date_active, SYSDATE)
           AND ROWNUM = 1;


        -- 3. Override the location if a valid configuration is found
        IF ln_override_loc_id IS NOT NULL THEN
             :new.ship_to_location_id := 1619359;
        END IF;

    EXCEPTION
        WHEN NO_DATA_FOUND THEN
             -- Vendor not in lookup, proceed normally
             NULL; 
        WHEN OTHERS THEN
             -- Catch-all for conversion errors, let normal logic stand
             NULL;
    END;
    -- =======================================================================
    -- END 1.8
    -- =======================================================================

     --D2P-1785 - Start
    lv_po_match_option := nvl(:new.match_option, 'Z');
    BEGIN
        SELECT
            poh.segment1,
            nvl(poh.authorization_status, 'INCOMPLETE'),
            nvl(ss.match_option, 'Z'),
            poh.interface_source_code --1.4
        INTO
            lv_po_num,
            lv_po_status,
            lv_ss_match_option,
            lv_source_code--1.4
        FROM
            po_headers_all        poh,
            ap_suppliers          s,
            ap_supplier_sites_all ss
        WHERE
                ss.vendor_site_id = poh.vendor_site_id
            AND ss.vendor_id = s.vendor_id
            AND s.vendor_id = poh.vendor_id
            AND poh.po_header_id = :old.po_header_id;

    EXCEPTION
        WHEN no_data_found THEN
            lv_po_num := NULL;
            lv_po_status := NULL;
            lv_ss_match_option := NULL;
            lv_source_code := NULL; --1.4
    END;

    IF
        lv_po_num LIKE 'NP%'
        AND lv_po_status = 'INCOMPLETE'
        AND lv_po_match_option <> lv_ss_match_option
        AND nvl(lv_source_code, 'XXX') <> 'OKC'
    THEN -- 1.4
        :new.match_option := lv_ss_match_option;
    END IF;

     --D2P-1785 - end

EXCEPTION
    WHEN OTHERS THEN
        lv_err := sqlerrm;
        xxpo_prefix_no_pkg.xxpo_prefix_err_proc(p_po_hdr_id => :old.po_header_id, p_po_num => :old.po_header_id, p_stats => 'E', p_err => lv_err
        , p_run_id => NULL);

END;
/
