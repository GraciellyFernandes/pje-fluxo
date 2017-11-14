-- For�ar charset: LATIN 1

begin;
CREATE OR REPLACE FUNCTION REDIST_PROC_COMP_EXCL(idProcesso integer, idOrgaoJulgadorDestino integer, idOrgaoJulgadorCargoDestino integer, isExtencao boolean)  RETURNS integer AS $$
DECLARE
    sequenceProcessoEvento integer;       
    idOrgaoJulgadorOrigem integer;
    numeroProcesso varchar;
    nomeOJOrigem varchar;
    nomeOJDestino varchar;
    nomeOJCargoDestino varchar;
    dsMotivoRedistribuicao varchar;
    dsPlavraMotivoRedistribuicao varchar;
    dsTipoRedistribuicao varchar; 

BEGIN

    select id_orgao_julgador into idOrgaoJulgadorOrigem from tb_processo_trf where id_processo_trf = $1; 
    select ds_orgao_julgador into nomeOJOrigem from tb_orgao_julgador where id_orgao_julgador = idOrgaoJulgadorOrigem;    
    select nr_processo into numeroProcesso from tb_processo where id_processo = $1;
    select ds_orgao_julgador into nomeOJDestino from tb_orgao_julgador where id_orgao_julgador = $2;
    select ds_cargo into nomeOJCargoDestino from tb_orgao_julgador_cargo where id_orgao_julgador_cargo = $3;

    IF idOrgaoJulgadorOrigem is NULL THEN
        RAISE EXCEPTION 'Processo de id % n�o existe ou n�o est� distribu�do!', $1;
        RETURN NULL;
    END IF;

    IF nomeOJDestino is NULL THEN
        RAISE EXCEPTION '�rg�o Julgador % de destino n�o existe!', $2;
        RETURN NULL;
    END IF;

    IF nomeOJCargoDestino is NULL THEN
        RAISE EXCEPTION 'Cargo % de �rg�o Julgador de destino n�o existe!', $3;
        RETURN NULL; 
    END IF;

    IF $4 THEN
        RAISE NOTICE 'Atribuindo motivo de extin��o...';
        dsPlavraMotivoRedistribuicao := 'extin��o';
        dsTipoRedistribuicao := 'X';
    ELSE
        RAISE NOTICE'Atribuindo motivo de cria��o...';        
        dsPlavraMotivoRedistribuicao := 'cria��o';
        dsTipoRedistribuicao := 'U';
    END IF;

    RAISE NOTICE 'Redistribuindo processo % para % por % ...',numeroProcesso,nomeOJDestino,dsPlavraMotivoRedistribuicao;

    RAISE NOTICE 'Atualizando tb_processo_trf ...';
    EXECUTE 'update tb_processo_trf set id_orgao_julgador_cargo =' ||$3||', id_orgao_julgador = '||$2||', dt_distribuicao = now() where id_processo_trf = '||$1||';';
    EXECUTE 'insert into tb_proc_trf_redistribuicao (id_processo_trf_redistribuicao,id_processo_trf,id_tipo_redistribuicao,id_orgao_julgador,ds_motivo_redistribuicao,dt_redistribuicao,id_motivo_redistribuicao,id_evento_redistribuicao,in_tipo_redistribuicao,id_usuario,id_orgao_julgador_anterior,in_tipo_distribuicao,id_orgao_julgador_colegiado_anterior,id_orgao_julgador_colegiado) values ((select nextval (''sq_tb_proc_trf_redistribuicao'')),'||$1||',null,'||$2||',''Por '||dsPlavraMotivoRedistribuicao||' de unidade judici�ria'',(now()),null,null,'''||dsTipoRedistribuicao||''',1,'||idOrgaoJulgadorOrigem||',''CE'',null,null);';
    select nextval('sq_tb_processo_evento') into sequenceProcessoEvento;    
    EXECUTE 'insert into tb_processo_evento (id_processo_evento,id_processo,id_evento,id_usuario,dt_atualizacao,id_jbpm_task,id_processo_documento,id_process_instance,id_tarefa,ds_nome_usuario,ds_cpf_usuario,ds_cnpj_usuario,in_processado,in_verificado_processado,tp_processo_evento,ds_texto_final_externo,ds_texto_final_interno,id_processo_evento_excludente,in_visibilidade_externa,ds_texto_parametrizado,ds_processo_evento,ds_observacao,in_ativo) values ('||sequenceProcessoEvento||','||$1||',246,1,(now()),null,null,null,null,null,null,null,false,false,''E'',''Redistribu�do por compet�ncia exclusiva em raz�o de '||dsPlavraMotivoRedistribuicao||' de unidade judici�ria'',''Redistribu�do por compet�ncia exclusiva em raz�o de '||dsPlavraMotivoRedistribuicao||' de unidade judici�ria'',null,true,''Redistribu�do por #{tipo_de_distribuicao_redistribuicao} em raz�o de #{motivo_da_redistribuicao}'',null,null,true);';
    EXECUTE 'insert into tb_complemento_segmentado (id_complemento_segmentado,vl_ordem,ds_texto,ds_valor_complemento,id_movimento_processo,id_tipo_complemento,in_visibilidade_externa,in_multivalorado ) values ((nextval(''sq_tb_complemento_segmentado'')),0,''1'',''compet�ncia exclusiva'','||sequenceProcessoEvento||',31,true,false);';
    EXECUTE 'insert into tb_complemento_segmentado (id_complemento_segmentado,vl_ordem,ds_texto,ds_valor_complemento,id_movimento_processo,id_tipo_complemento,in_visibilidade_externa,in_multivalorado ) values ((nextval(''sq_tb_complemento_segmentado'')),0,''89'','''||dsPlavraMotivoRedistribuicao||' de unidade judici�ria'','||sequenceProcessoEvento||',45,true,false);';
    EXECUTE 'update tb_processo_instance set id_orgao_julgador = null, id_orgao_julgador_cargo = null where id_processo = '||$1||';';
    EXECUTE 'update tb_processo set id_caixa = null where id_processo = '||$1||';';

    RAISE NOTICE 'Redistribui��o realizada com sucesso para o processo n� %!',numeroProcesso;

    return null;
END;
$$
LANGUAGE 'plpgsql';
commit;


-- Fun��o para redistribui��o nos juizados da fazenda
begin;
CREATE OR REPLACE FUNCTION REDIST_JEF_NEW(idOrgaoJulgadorRedist integer)  RETURNS integer AS $$
DECLARE
    /* OJ's que receber�o distribui��o dos processos.    

    - D�gitos 0 (zero), 8 (oito) e 9 (nove) do 3� Juizado 
    redistribu�dos para o 6� Juizado Especial da Fazenda P�blica da comarca de Natal.

    - D�gitos 0 (zero), 1 (um), 4 (quatro), 5 (cinco) e 6 (seis) do 4� Juizado 
     redistribu�dos para o 6� Juizado Especial da Fazenda P�blica da comarca de Natal.

     select oj.ds_orgao_julgador, oj.id_orgao_julgador, oc.id_orgao_julgador_cargo from tb_orgao_julgador oj
    join tb_orgao_julgador_cargo oc using(id_orgao_julgador)
    where ds_orgao_julgador ilike '%juiz%faz%natal' and oc.in_recebe_distribuicao = true

    Org�o Julgador               | ID  | ID_CARGO
    ----------------------------------------------
    1� Juizado da Fazenda Natal  | 38  |  79
    2� Juizado da Fazenda Natal  | 39  |  134
    3� Juizado da Fazenda Natal  | 102 |  252
    4� Juizado da Fazenda Natal  | 113 |  272
    5� Juizado da Fazenda Natal  | 115 |  274
    6� Juizado da Fazenda Natal  | 117 |  279
    */

    -- ID's dos OJ envolvidos na redistriui��o
    idOj_1JEF CONSTANT integer := 38;
    idOjCargo_1JEF CONSTANT integer := 79;
    idOj_2JEF CONSTANT integer := 39;
    idOjCargo_2JEF CONSTANT integer := 134;
    idOj_3JEF CONSTANT integer := 102;
    idOjCargo_3JEF CONSTANT integer := 252;
    idOj_4JEF CONSTANT integer := 113;
    idOjCargo_4JEF CONSTANT integer := 272;
    idOj_5JEF CONSTANT integer := 115;
    idOjCargo_5JEF CONSTANT integer := 274;   
    idOj_6JEF CONSTANT integer := 117;
    idOjCargo_6JEF CONSTANT integer := 278;       
    dsOrgaoJulgadorRedistribuicao varchar;        
    result RECORD;
    digitoConsiderado integer;

BEGIN

    select ds_orgao_julgador into dsOrgaoJulgadorRedistribuicao from tb_orgao_julgador where id_orgao_julgador = $1;    

    if dsOrgaoJulgadorRedistribuicao is NULL then
    RAISE EXCEPTION '�rg�o Julgador % n�o existe!', $1;
    RETURN NULL;
    END IF;

    RAISE NOTICE 'Iniciando redistriui��o do(a) % ...', dsOrgaoJulgadorRedistribuicao;
    RAISE NOTICE '---------------------------------------------------------------------------';
    FOR result IN SELECT p.id_processo AS idProcesso,
                         p.nr_processo AS processo
                  FROM tb_processo p
                  JOIN tb_processo_trf pt ON pt.id_processo_trf = p.id_processo
                  WHERE pt.id_orgao_julgador = $1 AND pt.cd_processo_status = 'D' LOOP                    

        RAISE NOTICE 'Processo ID: % ', result.idProcesso;                
        RAISE NOTICE 'N�mero: % ', result.processo;       
        digitoConsiderado:= cast(SUBSTRING(result.processo,7,1) as integer);
        RAISE NOTICE 'D�gito a considerar: % ...', digitoConsiderado;       
        
    IF $1 = idOj_3JEF THEN -- Trata os casos do 3� Ju�zado                                                                  
    CASE WHEN (digitoConsiderado = 0 or digitoConsiderado = 8 or digitoConsiderado = 9) 
         THEN PERFORM REDIST_PROC_COMP_EXCL(result.idProcesso,idOj_6JEF,idOjCargo_6JEF,false);
         ELSE RAISE NOTICE 'D�gito n�o se encaixa na regra de distribui��o ...';
    END CASE;
    ELSIF  $1 = idOj_4JEF THEN -- Trata os casos do 4� Ju�zado
    CASE WHEN (digitoConsiderado = 0 or digitoConsiderado = 1 or digitoConsiderado = 4 or digitoConsiderado = 5 or digitoConsiderado = 6) 
        THEN PERFORM REDIST_PROC_COMP_EXCL(result.idProcesso,idOj_6JEF,idOjCargo_6JEF,false);                
        ELSE RAISE NOTICE 'D�gito n�o se encaixa na regra de distribui��o ...';
    END CASE;        
    END IF;
        RAISE NOTICE '---------------------------------------------------------------------------';
    END LOOP;   

    return null;
END;
$$
LANGUAGE 'plpgsql';
commit; 



begin;
select REDIST_JEF_NEW(102);
select REDIST_JEF_NEW(113);
commit;



--- Fazenda P�blica
begin;
CREATE OR REPLACE FUNCTION REDIST_FAZ_MOSS(idOrgaoJulgadorRedist integer)  RETURNS integer AS $$
DECLARE
    /* OJ

     select oj.ds_orgao_julgador, oj.id_orgao_julgador, oc.id_orgao_julgador_cargo from tb_orgao_julgador oj
    join tb_orgao_julgador_cargo oc using(id_orgao_julgador)
    where ds_orgao_julgador ilike '%juiz%faz%natal' and oc.in_recebe_distribuicao = true

    Org�o Julgador                                   | ID  | ID_CARGO
    --------------------------------------------------------------------
    1� Vara da Fazenda P�blica da Comarca de Mossor�   96      232
    2� Vara da Fazenda P�blica da Comarca de Mossor�   104     259
    3� Vara de Fazenda P�blica da Comarca de Mossor�   125     292



    */

    -- �rg�os Julgadores j� existentes
    idOj_1FAZMOS CONSTANT integer := 96;
    idOjCargo_1FAZMOS CONSTANT integer := 232;
    idOj_2FAZMOS CONSTANT integer := 104;
    idOjCargo_2FAZMOS CONSTANT integer := 259;
    
    -- �rg�o julgadores novos
    idOj_3FAZMOS CONSTANT integer := 125;
    idOjCargo_3FAZMOS CONSTANT integer := 292;
        
    dsOrgaoJulgadorRedistribuicao varchar;        
    result RECORD;
    digitoConsiderado integer;

BEGIN

    select ds_orgao_julgador into dsOrgaoJulgadorRedistribuicao from tb_orgao_julgador where id_orgao_julgador = $1;    

    if dsOrgaoJulgadorRedistribuicao is NULL then
    RAISE EXCEPTION '�rg�o Julgador % n�o existe!', $1;
    RETURN NULL;
    END IF;

    RAISE NOTICE 'Iniciando redistriui��o do(a) % considerando a regra por d�gito...', dsOrgaoJulgadorRedistribuicao;
    RAISE NOTICE '---------------------------------------------------------------------------';
    FOR result IN SELECT p.id_processo AS idProcesso,
                         p.nr_processo AS processo
                  FROM tb_processo p
                  JOIN tb_processo_trf pt ON pt.id_processo_trf = p.id_processo
                  WHERE pt.id_orgao_julgador = $1 AND pt.cd_processo_status = 'D' LOOP                    

        RAISE NOTICE 'Processo ID: % ', result.idProcesso;                
        RAISE NOTICE 'N�mero: % ', result.processo;       
        digitoConsiderado:= cast(SUBSTRING(result.processo,7,1) as integer);
        RAISE NOTICE 'D�gito a considerar: % ...', digitoConsiderado;       
        
        IF $1 = idOj_1FAZMOS THEN -- Trata os casos da 1� Vara da Fazenda de Mossor�
            CASE WHEN (digitoConsiderado = 0 or digitoConsiderado = 1 or digitoConsiderado = 2 ) 
                    THEN PERFORM REDIST_PROC_COMP_EXCL(result.idProcesso,idOj_3FAZMOS,idOjCargo_3FAZMOS,false);                 
                 ELSE RAISE NOTICE 'D�gito n�o se encaixa na regra de distribui��o ...';
            END CASE;
         ELSIF  $1 = idOj_2FAZMOS THEN -- Trata os casos do 2� Vara da Fazenda de Mossor�
            CASE WHEN (digitoConsiderado = 0 or digitoConsiderado = 1 or digitoConsiderado = 2 ) 
                    THEN PERFORM REDIST_PROC_COMP_EXCL(result.idProcesso,idOj_3FAZMOS,idOjCargo_3FAZMOS,false);                 
                 ELSE RAISE NOTICE 'D�gito n�o se encaixa na regra de distribui��o ...';
            END CASE;     
         END IF;
        RAISE NOTICE '---------------------------------------------------------------------------';
    END LOOP;   

    return null;
END;
$$
LANGUAGE 'plpgsql';
commit; 


begin;
select REDIST_FAZ_MOSS(96);
select REDIST_FAZ_MOSS(104);
commit;


begin;
update tb_orgao_julgador_cargo set in_recebe_distribuicao = true, nr_acumulador_distribuicao = 1000, nr_acumulador_processo = 1000  where id_orgao_julgador_cargo in (232,259,292);    
commit;    


begin; 
CREATE OR REPLACE FUNCTION REDIST_FAM_MOSS(idOrgaoJulgadorRedist integer)  RETURNS integer AS $$
DECLARE
    /* OJ

    select oj.ds_orgao_julgador, oj.id_orgao_julgador, oc.id_orgao_julgador_cargo from tb_orgao_julgador oj
    join tb_orgao_julgador_cargo oc using(id_orgao_julgador)
    where ds_orgao_julgador ilike '%juiz%faz%natal' and oc.cd_sigla_cargo = 'JD'

    Org�o Julgador                                    | ID  | ID_CARGO
    --------------------------------------------------------------------
    1� Vara de Fam�lia da Comarca de Mossor�            89      207              
    2� Vara de Fam�lia da Comarca de Mossor�            90      215
    3� Vara de Fam�lia da Comarca de Mossor�            91      228
    4� Vara de Fam�lia da Comarca de Mossor�            92      226
    2� Vara de Fam�lia da Comarca de Mossor� (Nova)     126     293

    */

    -- �rg�os Julgadores j� existentes
    idOj_1FAM_MOS CONSTANT integer := 89;
    idOjCargo_1FAM_MOS CONSTANT integer := 207;
    idOj_2FAM_MOS CONSTANT integer := 90;
    idOjCargo_2FAM_MOS CONSTANT integer := 215;
    idOj_3FAM_MOS CONSTANT integer := 91;
    idOjCargo_3FAM_MOS CONSTANT integer := 228;
    idOj_4FAM_MOS CONSTANT integer := 92;
    idOjCargo_4FAM_MOS CONSTANT integer := 226;
    
    -- �rg�o julgadores novos
    idOj_2FAM_MOS_NOVA CONSTANT integer := 126;
    idOjCargo_2FAM_MOS_NOVA CONSTANT integer := 293;
        
    dsOrgaoJulgadorRedistribuicao varchar;        
    result RECORD;
    result_dig9 RECORD;
    digitoConsiderado integer;

    -- Contadores de processos redistribu�dos
    cont1VFAM integer;
    cont2VFAM_NOVA integer;
    cont3VFAM integer;
    cont4VFAM integer;

    -- orgao julgador e cargo a receber menor quantidade de processos reditribuidos
    idOJ_Menor_proc integer;
    idOJ_Cargo_Menor_proc integer;

BEGIN

    cont1VFAM := 0;
    cont2VFAM_NOVA := 0;
    cont3VFAM := 0;
    cont4VFAM := 0;

    select ds_orgao_julgador into dsOrgaoJulgadorRedistribuicao from tb_orgao_julgador where id_orgao_julgador = $1;    

    if dsOrgaoJulgadorRedistribuicao is NULL then
    RAISE EXCEPTION '�rg�o Julgador % n�o existe!', $1;
    RETURN NULL;
    END IF;

    RAISE NOTICE 'Iniciando redistriui��o do(a) % considerando a regra por d�gito...', dsOrgaoJulgadorRedistribuicao;
    RAISE NOTICE '---------------------------------------------------------------------------';
    FOR result IN SELECT p.id_processo AS idProcesso,
                         p.nr_processo AS processo
                  FROM tb_processo p
                  JOIN tb_processo_trf pt ON pt.id_processo_trf = p.id_processo
                  WHERE pt.id_orgao_julgador = $1 AND pt.cd_processo_status = 'D' LOOP                    

        RAISE NOTICE 'Processo ID: % ', result.idProcesso;                
        RAISE NOTICE 'N�mero: % ', result.processo;       
        digitoConsiderado:= cast(SUBSTRING(result.processo,7,1) as integer);
        RAISE NOTICE 'D�gito a considerar: % ...', digitoConsiderado;       
        
        IF $1 = idOj_2FAM_MOS THEN -- Trata os casos da 2� Vara da Fam�lia de Mossor�
            CASE WHEN (digitoConsiderado = 0 or digitoConsiderado = 1 or digitoConsiderado = 2) 
                    THEN 
                        PERFORM REDIST_PROC_COMP_EXCL(result.idProcesso,idOj_1FAM_MOS,idOjCargo_1FAM_MOS,false);   
                        cont1VFAM := cont1VFAM + 1;
                WHEN (digitoConsiderado = 3 or digitoConsiderado = 4 or digitoConsiderado = 5) 
                    THEN 
                        PERFORM REDIST_PROC_COMP_EXCL(result.idProcesso,idOj_2FAM_MOS_NOVA,idOjCargo_2FAM_MOS_NOVA,false);                 
                        cont2VFAM_NOVA := cont2VFAM_NOVA + 1;
                WHEN (digitoConsiderado = 6 or digitoConsiderado = 7 or digitoConsiderado = 8) 
                    THEN 
                        PERFORM REDIST_PROC_COMP_EXCL(result.idProcesso,idOj_3FAM_MOS,idOjCargo_3FAM_MOS,false);                     
                        cont3VFAM := cont3VFAM + 1;
        ELSE RAISE NOTICE 'D�gito 9 ser� tratado em seguida ...';
            END CASE;     
        ELSIF  $1 = idOj_4FAM_MOS THEN -- Trata os casos do 4� Vara da Fam�lia de Mossor�            
             PERFORM REDIST_PROC_COMP_EXCL(result.idProcesso,idOj_2FAM_MOS_NOVA,idOjCargo_2FAM_MOS_NOVA,false);                                             
             cont2VFAM_NOVA := cont2VFAM_NOVA + 1;
        END IF;
        RAISE NOTICE '---------------------------------------------------------------------------';
    END LOOP;   

    RAISE NOTICE 'Quantitavivo de processos recebidos por �rg�o Julgador...';       
    RAISE NOTICE '1� Vara de Fam�lia da Comarca de Mossor�: % ...', cont1VFAM;       
    RAISE NOTICE '2� Vara de Fam�lia da Comarca de Mossor� (NOVA): % ...', cont2VFAM_NOVA;       
    RAISE NOTICE '3� Vara de Fam�lia da Comarca de Mossor�: % ...', cont3VFAM;       

    -- Verifica qual �rgao julgador recebeu menor n�mero de processos redistribuidos
    IF (cont1VFAM <= cont2VFAM_NOVA AND cont1VFAM <= cont3VFAM)THEN    
        RAISE NOTICE '�rg�o Julgador com menor quantidade: 1� Vara de Fam�lia da Comarca de Mossor�';       
        idOJ_Menor_proc := idOj_1FAM_MOS;
        idOJ_Cargo_Menor_proc := idOjCargo_1FAM_MOS;
    ELSIF (cont2VFAM_NOVA <= cont1VFAM AND cont2VFAM_NOVA <= cont3VFAM) THEN
        RAISE NOTICE '�rg�o Julgador com menor quantidade: 2� Vara de Fam�lia da Comarca de Mossor� (Nova)';       
        idOJ_Menor_proc := idOj_2FAM_MOS_NOVA;
        idOJ_Cargo_Menor_proc := idOjCargo_2FAM_MOS_NOVA;
    ELSIF (cont3VFAM <= cont1VFAM AND cont3VFAM <= cont2VFAM_NOVA) THEN
        RAISE NOTICE '�rg�o Julgador com menor quantidade: 3� Vara de Fam�lia da Comarca de Mossor�';       
        idOJ_Menor_proc := idOj_3FAM_MOS;
        idOJ_Cargo_Menor_proc := idOjCargo_3FAM_MOS;
    END IF;

    IF $1 = idOj_2FAM_MOS THEN -- Trata os casos da 2� Vara da Fam�lia de Mossor�
    -- Processos com termina��o 9
        RAISE NOTICE 'Iniciando redistriui��o do(a) % considerando a regra por d�gito 9 para orgao julgador com menor quantidade de processos redistribu�dos...', dsOrgaoJulgadorRedistribuicao;
        RAISE NOTICE '---------------------------------------------------------------------------';
         FOR result_dig9 IN SELECT  p.id_processo AS idProcesso,
                                    p.nr_processo AS processo
                        FROM tb_processo p
                        JOIN tb_processo_trf pt ON pt.id_processo_trf = p.id_processo
                        WHERE pt.id_orgao_julgador = $1 AND pt.cd_processo_status = 'D' AND cast(SUBSTRING( p.nr_processo,7,1) as integer) = 9 LOOP
        
            RAISE NOTICE 'Processo ID: % ', result_dig9.idProcesso;                
            RAISE NOTICE 'N�mero: % ', result_dig9.processo;       
            digitoConsiderado:= cast(SUBSTRING(result_dig9.processo,7,1) as integer);
            RAISE NOTICE 'D�gito a considerar: % ...', digitoConsiderado;  

            PERFORM REDIST_PROC_COMP_EXCL(result_dig9.idProcesso,idOJ_Menor_proc,idOJ_Cargo_Menor_proc,false);                     

        RAISE NOTICE '---------------------------------------------------------------------------';
        END LOOP;  
    END IF; 
        


    return null;
END;
$$
LANGUAGE 'plpgsql';
commit; 


begin;
select REDIST_FAM_MOSS(90);
select REDIST_FAM_MOSS(92);
commit;

-- configura��o
begin;
update tb_orgao_julgador_cargo SET in_ativo = false, in_recebe_distribuicao = false where  id_orgao_julgador_cargo = 215;
update tb_orgao_julgador set ds_orgao_julgador = ds_orgao_julgador || ' (Inativada pela Resolu��o 29/2017)', in_ativo = false where id_orgao_julgador = 90;
update tb_orgao_julgador_cargo SET in_ativo = false, in_recebe_distribuicao = false where  id_orgao_julgador_cargo = 226;
update tb_orgao_julgador set ds_orgao_julgador = ds_orgao_julgador || ' (Inativada pela Resolu��o 29/2017)', in_ativo = false where id_orgao_julgador = 92;
update tb_localizacao set ds_localizacao = ds_localizacao || '(Inativada pela Resolu��o 29/2017)' where id_localizacao = 6212;
update tb_localizacao set ds_localizacao = '2� Vara de Fam�lia da Comarca de Mossor�'  where id_localizacao = 32294;
update tb_orgao_julgador set ds_orgao_julgador = '2� Vara de Fam�lia da Comarca de Mossor�' where id_orgao_julgador = 126;
update tb_orgao_julgador_cargo set in_ativo = true, in_recebe_distribuicao = true where id_orgao_julgador_cargo = 293;
update tb_orgao_julgador_cargo set in_recebe_distribuicao = true, nr_acumulador_distribuicao = 1000, nr_acumulador_processo = 1000  where id_orgao_julgador_cargo in (293,207,228);        
commit;