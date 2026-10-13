CREATE OR REPLACE PROCEDURE TEST_SPECIAL_CHARS
/*--===================================================================
    Purpose: Test that special characters survive FlexDeploy deployment.
             No tables or dependent objects are used.
             Each literal below is compared against its UNISTR() value,
             which is built inside the database and is not affected by
             file encoding.
    Characters tested: ö ô » £ ¥
--===================================================================*/
(
    O_Result OUT VARCHAR2
) IS

    v_out VARCHAR2(4000);

    PROCEDURE check_char(p_name VARCHAR2, p_literal VARCHAR2, p_expected VARCHAR2) IS
        v_dump VARCHAR2(200);
        v_status VARCHAR2(4);
    BEGIN
        SELECT DUMP(p_literal, 1016) INTO v_dump FROM dual;
        IF p_literal = p_expected THEN
            v_status := 'PASS';
        ELSE
            v_status := 'FAIL';
        END IF;
        v_out := v_out || v_status || ' ' || p_name || ' [' || p_literal || '] ' || v_dump || CHR(10);
    END check_char;

BEGIN
    check_char('o-umlaut     ', 'ö', UNISTR('\00F6'));
    check_char('o-circumflex ', 'ô', UNISTR('\00F4'));
    check_char('right-guill  ', '»', UNISTR('\00BB'));
    check_char('pound        ', '£', UNISTR('\00A3'));
    check_char('yen          ', '¥', UNISTR('\00A5'));

    -- Same idea as BUILD_REQSET_EXT: replace < > with ö ô and use » as a delimiter
    v_out := v_out || 'Sample: '
          || REPLACE(REPLACE('<Remarks>', '<', 'ö'), '>', 'ô')
          || '»' || 'field2' || '»' || 'field3' || CHR(10);

    O_Result := v_out;
    DBMS_OUTPUT.PUT_LINE(v_out);
END TEST_SPECIAL_CHARS;
