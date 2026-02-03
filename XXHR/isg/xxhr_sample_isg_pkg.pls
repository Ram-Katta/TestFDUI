CREATE OR REPLACE PACKAGE xxhr_sample_isg_pkg AS
  /* $Header: xxhr_sample_isg_pkg.pls */
  /*#
  * Sample Package
  */
-- *************************************************************************
-- Program Name       : xxhr_sample_isg_pkg.pks
-- Purpose            : Sample ISG
-- History:
---------------------------------------------------------------------------
-- Date          Author                      Description
---------------------------------------------------------------------------
-- 06/27/2025   Ben Hoffman                  Initial version
-- ************************************************************************* 

TYPE serial_number_rec_type  IS RECORD (serial_number VARCHAR2(30));

TYPE serial_number_tbl_type  IS TABLE OF serial_number_rec_type;

TYPE item_number_rec_type IS RECORD (item_number  VARCHAR2(30),
                                     item_quantity NUMBER,
									 serial_array serial_number_tbl_type);

TYPE item_number_tbl_type  IS TABLE OF item_number_rec_type;

TYPE xxceoe_wls_carton_rec_type IS RECORD
       (carton_id varchar2(50), 
		oem varchar2(100), 
		device_count number, 
		carton_action varchar2(30),
        item_details item_number_tbl_type);

TYPE xxceoe_wls_carton_tbl_type  IS TABLE OF xxceoe_wls_carton_rec_type;

  

PROCEDURE process_freeze (p_auc_tbl xxceoe_wls_auc_tbl_type,
                          x_return_status out varchar2,
						  x_return_message out varchar2);

PROCEDURE extract_carton_dtls (p_carton_id in varchar2,
                               p_action in varchar2,
							   x_carton_tbl out xxceoe_wls_carton_tbl_type,
							   x_ret_code out varchar2,
							   x_ret_message out varchar2)
 /*#
    * This procedure extracts wireless device carton details from Oracle
    * @param p_carton_id               IN  VARCHAR2
    * @param p_action             	   IN  VARCHAR2
    * @param x_carton_tbl              OUT xxceoe_wls_carton_tbl_type
    * @param x_ret_code                OUT VARCHAR2
    * @param x_ret_message             OUT VARCHAR2
    * @rep:scope public
    * @rep:lifecycle active
    * @rep:displayname Publish Cox Wireless Carton Details
    * @rep:compatibility S
    * @rep:category BUSINESS_ENTITY ONT
    */
;
						  
PROCEDURE update_freeze_status (p_carton_id in varchar2,
                                p_action in varchar2,
								p_status in varchar2,
								p_status_msg in varchar2,
								x_ret_code out varchar2,
								x_ret_message out varchar2)
/*#
    * This procedure updates carton status in Oracle
    * @param p_carton_id               IN  VARCHAR2
    * @param p_action             	   IN  VARCHAR2
	* @param p_status                  IN  VARCHAR2
    * @param p_status_msg              IN  VARCHAR2
    * @param x_ret_code                OUT VARCHAR2
    * @param x_ret_message             OUT VARCHAR2
    * @rep:scope public
    * @rep:lifecycle active
    * @rep:displayname Update Cox Wireless Carton Status
    * @rep:compatibility S
    * @rep:category BUSINESS_ENTITY ONT
    */								
;		

				
						
PROCEDURE create_order (p_auc_tbl in xxceoe_wls_auc_tbl_type,
                        x_return_status out varchar2,
						x_return_message out varchar2);

END xxhr_sample_isg_pkg;