begin;
CREATE OR REPLACE FUNCTION REDIST_4VFAM_2VFAM()  RETURNS integer AS $$
DECLARE
    -- ID's dos OJ envolvidos na redistriui��o
    idOj_4VFAM CONSTANT integer := 92;

    -- OJ NOVO
    idOj_2VFAM_NEW CONSTANT integer := 257;
    
    idOjCargo_2VFAM_NEW CONSTANT integer := 647;    

    dsOrgaoJulgadorRedistribuicao varchar;        
    result RECORD;
    digitoConsiderado integer;

BEGIN

    select ds_orgao_julgador into dsOrgaoJulgadorRedistribuicao from tb_orgao_julgador where id_orgao_julgador = idOj_4VFAM;    

    if dsOrgaoJulgadorRedistribuicao is NULL then
    RAISE EXCEPTION '�rg�o Julgador % n�o existe!', idOj_4VFAM;
    RETURN NULL;
    END IF;

    RAISE NOTICE 'Iniciando redistriui��o do(a) % ...', dsOrgaoJulgadorRedistribuicao;
    RAISE NOTICE '---------------------------------------------------------------------------';
    FOR result IN 
                SELECT  p.id_processo AS idProcesso,
                        p.nr_processo AS processo
                FROM tb_processo p
                JOIN tb_processo_trf pt ON pt.id_processo_trf = p.id_processo
                WHERE pt.id_orgao_julgador = idOj_4VFAM AND pt.cd_processo_status = 'D'
--                and pt.id_processo_trf = 1226803
    LOOP                    

        RAISE NOTICE 'Processo ID: % ', result.idProcesso;                
        RAISE NOTICE 'N�mero: % ', result.processo;
                    
        PERFORM REDIST_PROC_COMP_EXCL(result.idProcesso,idOj_2VFAM_NEW,idOjCargo_2VFAM_NEW,false, true);
        
        RAISE NOTICE '---------------------------------------------------------------------------';
    END LOOP;   

    return null;
END;
$$
LANGUAGE 'plpgsql';
commit; 