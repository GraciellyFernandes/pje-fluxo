
begin;
CREATE OR REPLACE FUNCTION REDIST_MAC_DIG(idOrgaoJulgadorRedist integer)  RETURNS integer AS $$
DECLARE
    /* OJ's que receber�o distribui��o dos processos.    

     - Os d�gitos 0, 1 e 2 das 1� e 2� Varas C�veis ir�o para a 1� Vara;
	 - Os d�gitos 3, 4 e 5 das 1� e 2� Varas C�veis ir�o para a 2� Vara. 
	 - Os d�gitos 6, 7, 8 e 9 das 1� e 2� Varas C�veis ir�o para a 3� Vara.

     select oj.ds_orgao_julgador, oj.id_orgao_julgador, oc.id_orgao_julgador_cargo from tb_orgao_julgador oj
	join tb_orgao_julgador_cargo oc using(id_orgao_julgador)
	where ds_orgao_julgador ilike '%juiz%faz%natal' and oc.in_recebe_distribuicao = true

    Org�o Julgador                      		     | ID  | ID_CARGO
    ---------------------------------------------------------------
	1� Vara C�vel da Comarca de Maca�ba	          	   80	 190
	2� Vara C�vel da Comarca de Maca�ba	               81	 193	
	1� Vara de Maca�ba								   118	 281
	2� Vara de Maca�ba								   119	 282
	3� Vara de Maca�ba								   120	 283

    */

    -- �rg�os Julgadores j� existentes
    idOj_1VCIVMAC CONSTANT integer := 80;
    idOjCargo_1VCIVMAC CONSTANT integer := 190;
    idOj_2VCIVMAC CONSTANT integer := 81;
    idOjCargo_2VCIVMAC CONSTANT integer := 193;
    
    -- Novos �rg�os julgadores
    idOj_1VMAC_JEF CONSTANT integer := 118;
    idOjCargo_1VMAC CONSTANT integer := 281;
    idOj_2VMAC_JEF CONSTANT integer := 119;
    idOjCargo_2VMAC CONSTANT integer := 282;
    idOj_3VMAC_JEF CONSTANT integer := 120;
    idOjCargo_3VMAC CONSTANT integer := 283;
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
		
		IF $1 = idOj_1VCIVMAC THEN -- Trata os casos da 1� Vara C�vel de Maca�ba																    
	        CASE WHEN (digitoConsiderado = 0 or digitoConsiderado = 1 or digitoConsiderado = 2) THEN PERFORM REDIST_PROC_COMP_EXCL(result.idProcesso,idOj_1VMAC_JEF,idOjCargo_1VMAC,false);
	        	 WHEN (digitoConsiderado = 3 or digitoConsiderado = 4 or digitoConsiderado = 5) THEN PERFORM REDIST_PROC_COMP_EXCL(result.idProcesso,idOj_2VMAC_JEF,idOjCargo_2VMAC,false);
	        	 WHEN (digitoConsiderado = 6 or digitoConsiderado = 7 or digitoConsiderado = 8 or digitoConsiderado = 9) THEN PERFORM REDIST_PROC_COMP_EXCL(result.idProcesso,idOj_3VMAC_JEF,idOjCargo_3VMAC,false);
	             ELSE RAISE NOTICE 'D�gito n�o se encaixa na regra de distribui��o ...';
	        END CASE;
	     ELSIF  $1 = idOj_2VCIVMAC THEN -- Trata os casos da 2� Vara C�vel de Maca�ba
	        CASE WHEN (digitoConsiderado = 0 or digitoConsiderado = 1 or digitoConsiderado = 2) THEN PERFORM REDIST_PROC_COMP_EXCL(result.idProcesso,idOj_1VMAC_JEF,idOjCargo_1VMAC,false);
	        	 WHEN (digitoConsiderado = 3 or digitoConsiderado = 4 or digitoConsiderado = 5) THEN PERFORM REDIST_PROC_COMP_EXCL(result.idProcesso,idOj_2VMAC_JEF,idOjCargo_2VMAC,false);
	        	 WHEN (digitoConsiderado = 6 or digitoConsiderado = 7 or digitoConsiderado = 8 or digitoConsiderado = 9) THEN PERFORM REDIST_PROC_COMP_EXCL(result.idProcesso,idOj_3VMAC_JEF,idOjCargo_3VMAC,false);
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

 -- Fun��o para redistribui��o nos juizados da fazenda
begin;
CREATE OR REPLACE FUNCTION REDIST_MAC_COMP(idOrgaoJulgadorRedist integer)  RETURNS integer AS $$
DECLARE
    /* 

     - A 2� Vara ter� compet�ncia exclusiva de "Registro Publico" e "Fam�lia"


     select oj.ds_orgao_julgador, oj.id_orgao_julgador, oc.id_orgao_julgador_cargo from tb_orgao_julgador oj
    join tb_orgao_julgador_cargo oc using(id_orgao_julgador)
    where ds_orgao_julgador ilike '%juiz%faz%natal' and oc.in_recebe_distribuicao = true

    Org�o Julgador                                   | ID  | ID_CARGO
    ---------------------------------------------------------------
    1� Vara C�vel da Comarca de Maca�ba                80    190
    2� Vara C�vel da Comarca de Maca�ba                81    193        
    2� Vara de Maca�ba                                 119   282    

    */

    -- �rg�os Julgadores j� existentes
    idOj_1VCIVMAC CONSTANT integer := 80;
    idOjCargo_1VCIVMAC CONSTANT integer := 190;
    idOj_2VCIVMAC CONSTANT integer := 81;
    idOjCargo_2VCIVMAC CONSTANT integer := 193;
    
    -- Novos �rg�os julgadores    
    idOj_2VMAC_JEF CONSTANT integer := 119;
    idOjCargo_2VMAC CONSTANT integer := 282;    
    dsOrgaoJulgadorRedistribuicao varchar;        
    result RECORD;    

BEGIN

    select ds_orgao_julgador into dsOrgaoJulgadorRedistribuicao from tb_orgao_julgador where id_orgao_julgador = $1;    

    if dsOrgaoJulgadorRedistribuicao is NULL then
    RAISE EXCEPTION '�rg�o Julgador % n�o existe!', $1;
    RETURN NULL;
    END IF;

    RAISE NOTICE 'Iniciando redistriui��o do(a) % considerando a regra por compet�ncia privativa (Fam�lia e Registro P�blico)...', dsOrgaoJulgadorRedistribuicao;
    RAISE NOTICE '---------------------------------------------------------------------------';
    FOR result IN SELECT   p.id_processo AS idProcesso,
                           p.nr_processo AS processo
                      FROM tb_processo p
                      JOIN tb_processo_trf pt ON pt.id_processo_trf = p.id_processo   /* Registro P�blico e Fam�lia*/               
                      WHERE pt.id_orgao_julgador = $1 AND pt.cd_processo_status = 'D' AND pt.id_competencia in (13,20) LOOP                    

        RAISE NOTICE 'Processo ID: % ', result.idProcesso;                
        RAISE NOTICE 'N�mero: % ', result.processo;        
        
        PERFORM REDIST_PROC_COMP_EXCL(result.idProcesso,idOj_2VMAC_JEF,idOjCargo_2VMAC,false);
        
        RAISE NOTICE '---------------------------------------------------------------------------';
    END LOOP;   

    return null;
END;
$$
LANGUAGE 'plpgsql';
commit; 

begin;
select REDIST_MAC_COMP(80);
select REDIST_MAC_COMP(81);
commit;

begin;
select REDIST_MAC_DIG(80);
select REDIST_MAC_DIG(81);
commit;

begin;
update tb_orgao_julgador_cargo set in_recebe_distribuicao = true where id_orgao_julgador_cargo in (281,282,283);
update tb_orgao_julgador_cargo set in_recebe_distribuicao = true where id_orgao_julgador_cargo in (190,193);
update tb_orgao_julgador_cargo set nr_acumulador_distribuicao = 1000, nr_acumulador_processo = 1000 where id_orgao_julgador_cargo in (281,282,283);
update tb_orgao_julgador set ds_orgao_julgador = '1� Vara C�vel da Comarca de Maca�ba (Inativada pela Resolu��o 30/2017)', in_ativo = false where id_orgao_julgador = 80;
update tb_orgao_julgador set ds_orgao_julgador = '2� Vara C�vel da Comarca de Maca�ba (Inativada pela Resolu��o 30/2017)', in_ativo = false where id_orgao_julgador = 81;
update tb_jurisdicao set ds_jurisdicao = 'Justi�a Comum C�vel - Maca�ba' where id_jurisdicao = 28;
update tb_jurisdicao set in_ativo = false where id_jurisdicao = 29;
commit;

