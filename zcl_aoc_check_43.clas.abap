class ZCL_AOC_CHECK_43 definition
  public
  inheriting from ZCL_AOC_SUPER
  create public .

public section.
*"* public components of class ZCL_AOC_CHECK_43
*"* do not include other source files here!!!

  methods CONSTRUCTOR .

  methods CHECK
    redefinition .
  methods GET_MESSAGE_TEXT
    redefinition .
protected section.
*"* protected components of class ZCL_AOC_CHECK_43
*"* do not include other source files here!!!
PRIVATE SECTION.
*"* private components of class ZCL_AOC_CHECK_43
*"* do not include other source files here!!!

  TYPES:
    BEGIN OF ty_call,
           class TYPE seoclsname,
           method TYPE string,
           start_line TYPE i,
           start_column TYPE token_col,
           end_line TYPE i,
           end_column TYPE token_col,
           program TYPE programm,
           level TYPE stmnt_levl,
         END OF ty_call .
  TYPES:
    ty_call_tt TYPE SORTED TABLE OF ty_call WITH NON-UNIQUE KEY level start_line .

  METHODS check_parameters
    IMPORTING
      !is_call TYPE ty_call
      !iv_code TYPE string .
  METHODS get_calls
    IMPORTING
      !it_levels TYPE slevel_tab
    RETURNING
      value(rt_calls) TYPE ty_call_tt .
ENDCLASS.



CLASS ZCL_AOC_CHECK_43 IMPLEMENTATION.


METHOD check.

* abapOpenChecks
* https://github.com/larshp/abapOpenChecks
* MIT License

  DATA: lt_calls  TYPE ty_call_tt,
        lv_index  TYPE i,
        lv_foobar TYPE string,                              "#EC NEEDED
        lv_str    TYPE string.

  FIELD-SYMBOLS: <ls_top>       LIKE LINE OF it_tokens,
                 <ls_token>     LIKE LINE OF it_tokens,
                 <ls_call>      LIKE LINE OF lt_calls,
                 <ls_statement> LIKE LINE OF it_statements.


  lt_calls = get_calls( it_levels ).
  IF lt_calls IS INITIAL.
    RETURN.
  ENDIF.

  LOOP AT it_statements ASSIGNING <ls_statement>.
    LOOP AT it_tokens ASSIGNING <ls_top> FROM <ls_statement>-from TO <ls_statement>-to.
      lv_index = sy-tabix.

      LOOP AT lt_calls ASSIGNING <ls_call>
          WHERE level = <ls_statement>-level
          AND start_line = <ls_top>-row
          AND start_column = <ls_top>-col.

        CLEAR lv_str.
        LOOP AT it_tokens ASSIGNING <ls_token> FROM lv_index TO <ls_statement>-to.
          IF <ls_token>-row > <ls_call>-end_line
              OR ( <ls_token>-row = <ls_call>-end_line
              AND <ls_token>-col + strlen( <ls_token>-str ) >= <ls_call>-end_column ).
            EXIT.
          ENDIF.
          IF lv_str IS INITIAL.
            lv_str = <ls_token>-str.
          ELSE.
            CONCATENATE lv_str <ls_token>-str INTO lv_str SEPARATED BY space.
          ENDIF.
        ENDLOOP.

        SPLIT lv_str AT '(' INTO lv_foobar lv_str.
        IF lv_str <> ''.
          check_parameters(
              is_call = <ls_call>
              iv_code = lv_str ).
        ENDIF.

      ENDLOOP.
    ENDLOOP.
  ENDLOOP.

ENDMETHOD.


METHOD check_parameters.

  TYPES: BEGIN OF ty_seosubcodf,
           clsname    TYPE seosubcodf-clsname,
           cmpname    TYPE seosubcodf-cmpname,
           sconame    TYPE seosubcodf-sconame,
           version    TYPE seosubcodf-version,
           paroptionl TYPE seosubcodf-paroptionl,
           parvalue   TYPE seosubcodf-parvalue,
           parpreferd TYPE seosubcodf-parpreferd,
         END OF ty_seosubcodf.

  DATA: lv_parameter  TYPE seosubcodf-sconame,
        lt_parameters TYPE TABLE OF ty_seosubcodf,
        lv_foobar     TYPE string,                          "#EC NEEDED
        lv_post       TYPE string.


  SPLIT iv_code AT '=' INTO lv_parameter lv_post.
  SPLIT lv_post AT ')' INTO lv_post lv_foobar.
  IF lv_post IS INITIAL OR lv_post CA '='.
    RETURN.
  ENDIF.
  CONDENSE lv_parameter.

  SELECT * FROM seosubcodf
    INTO CORRESPONDING FIELDS OF TABLE lt_parameters
    WHERE clsname = is_call-class
    AND cmpname = is_call-method
    AND pardecltyp = '0'
    AND type <> ''.
  IF sy-subrc <> 0.
    RETURN.
  ENDIF.
* in case there are multiple parameters filter out the optional
* if there is one importing parameter it is okay to be optional
  IF lines( lt_parameters ) > 1.
    DELETE lt_parameters WHERE ( paroptionl = abap_true OR parvalue <> '' )
      AND parpreferd = abap_false.
  ENDIF.

  IF lines( lt_parameters ) <> 1.
    RETURN.
  ENDIF.

  READ TABLE lt_parameters WITH KEY sconame = lv_parameter
    TRANSPORTING NO FIELDS.
  IF sy-subrc = 0.
    inform( p_sub_obj_type = c_type_include
            p_sub_obj_name = is_call-program
            p_line         = is_call-start_line
            p_kind         = mv_errty
            p_test         = myname
            p_code         = '001'
            p_param_1      = lv_parameter ).
  ENDIF.

ENDMETHOD.


METHOD constructor.

  super->constructor( ).

  description    = 'Parameter name can be omitted'.         "#EC NOTEXT
  category       = 'ZCL_AOC_CATEGORY'.
  version        = '001'.
  position       = '043'.

  has_attributes = abap_true.
  attributes_ok  = abap_true.

  mv_errty = c_error.

ENDMETHOD.                    "CONSTRUCTOR


METHOD get_calls.

  DATA: lt_result   TYPE scr_refs,
        lv_name     TYPE program,
        lv_class    TYPE seoclsname,
        lv_foobar   TYPE string,                            "#EC NEEDED
        ls_call     LIKE LINE OF rt_calls,
        lo_compiler TYPE REF TO cl_abap_compiler.

  FIELD-SYMBOLS: <ls_result> LIKE LINE OF lt_result.


  CASE object_type.
    WHEN 'PROG'.
      lv_name = object_name.
    WHEN 'CLAS'.
      lv_class = object_name.
      lv_name = cl_oo_classname_service=>get_classpool_name( lv_class ).
    WHEN 'FUGR'.
      CONCATENATE 'SAPL' object_name INTO lv_name.
    WHEN OTHERS.
      RETURN.
  ENDCASE.

  CREATE OBJECT lo_compiler
    EXPORTING
      p_name             = lv_name
      p_no_package_check = abap_true.

  lo_compiler->get_all(
    IMPORTING
      p_result = lt_result ).
  DELETE lt_result WHERE tag <> cl_abap_compiler=>tag_method.

  LOOP AT lt_result ASSIGNING <ls_result>.
    CLEAR ls_call.
    <ls_result>-full_name = <ls_result>-full_name+4.
    SPLIT <ls_result>-full_name AT '\ME:' INTO <ls_result>-full_name lv_foobar.
    IF <ls_result>-full_name CP '*\IN:*'.
      SPLIT <ls_result>-full_name AT '\IN:' INTO lv_foobar ls_call-class.
    ELSE.
      ls_call-class = <ls_result>-full_name.
    ENDIF.
    ls_call-method = <ls_result>-name.

    ls_call-start_line   = <ls_result>-statement->start_line.
    ls_call-start_column = <ls_result>-statement->start_column.
    ls_call-end_line     = <ls_result>-statement->end_line.
    ls_call-end_column   = <ls_result>-statement->end_column.

    ls_call-program = <ls_result>-statement->source_info->name.

    READ TABLE it_levels WITH KEY name = ls_call-program TRANSPORTING NO FIELDS.
    IF sy-subrc <> 0.
      CONTINUE.
    ENDIF.
    ls_call-level = sy-tabix.

    INSERT ls_call INTO TABLE rt_calls.
  ENDLOOP.

ENDMETHOD.


METHOD get_message_text.

  CASE p_code.
    WHEN '001'.
      p_text = 'Parameter name &1 can be omitted'.          "#EC NOTEXT
    WHEN OTHERS.
      ASSERT 1 = 1 + 1.
  ENDCASE.

ENDMETHOD.
ENDCLASS.