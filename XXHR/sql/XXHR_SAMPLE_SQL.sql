SET SERVEROUTPUT ON

BEGIN
    DBMS_OUTPUT.PUT_LINE('Script started...');
    DBMS_OUTPUT.PUT_LINE('DB Time: ' || TO_CHAR(SYSDATE, 'YYYY-MM-DD HH24:MI:SS'));
    DBMS_OUTPUT.PUT_LINE('Script completed successfully.');
END;
/

EXIT
