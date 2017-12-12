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
    1� Juizado da Fazenda Natal	 | 38  |  79
	2� Juizado da Fazenda Natal	 | 39  |  134
	3� Juizado da Fazenda Natal	 | 102 |  252
	4� Juizado da Fazenda Natal	 | 113 |  272
	5� Juizado da Fazenda Natal	 | 115 |  274
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
		
		IF $1 = idOj_3JEF THEN -- Trata os casos do 1� Ju�zado																    
	        CASE WHEN (digitoConsiderado = 0 or digitoConsiderado = 8 or digitoConsiderado = 9) 
	        	 THEN PERFORM REDIST_PROC_COMP_EXCL(result.idProcesso,idOj_6JEF,idOjCargo_6JEF,false);
	             ELSE RAISE NOTICE 'D�gito n�o se encaixa na regra de distribui��o ...';
	        END CASE;
	     ELSIF  $1 = idOj_4JEF THEN -- Trata os casos do 2� Ju�zado
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

