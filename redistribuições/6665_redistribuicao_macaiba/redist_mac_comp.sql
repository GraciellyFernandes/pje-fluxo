 -- Fun��o para redistribui��o nos juizados da fazenda
begin;
CREATE OR REPLACE FUNCTION REDIST_MAC_COMP(idOrgaoJulgadorRedist integer)  RETURNS integer AS $$
DECLARE
    /* 

     - A 2� Vara ter� compet�ncia exclusiva de "Registro Publico" e "Fam�lia"


     select oj.ds_orgao_julgador, oj.id_orgao_julgador, oc.id_orgao_julgador_cargo from tb_orgao_julgador oj
	join tb_orgao_julgador_cargo oc using(id_orgao_julgador)
	where ds_orgao_julgador ilike '%juiz%faz%natal' and oc.in_recebe_distribuicao = true

    Org�o Julgador                      		     | ID  | ID_CARGO
    ---------------------------------------------------------------
	1� Vara C�vel da Comarca de Maca�ba	          	   80	 190
	2� Vara C�vel da Comarca de Maca�ba	               81	 193		
	2� Vara de Maca�ba								   119	 282	

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

