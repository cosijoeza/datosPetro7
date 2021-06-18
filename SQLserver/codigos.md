# Tabla de reportes
~~~~sql
    use petro_desarrollo
    go 

    SELECT Id,Reporte,Query FROM dbo.Reportes 
    WHERE Id = 4
~~~~
# Actualizar POS
~~~~sql
    use Arcadia_cbos
    GO

    select * from journalclosenotification
    where journalclose_journalcloseid in (
        select j.journalcloseid 
        from journalclose j 
        inner join gasstation g
            on j.gasStation_gasStationID = g.gasstationid
        where g.posGasStationID = 6185
        and j.businessDate = '2021-05-26'
        and j.shift = 3
    );
~~~~
~~~~sql
    begin tran
        update journalclosenotification
        set operationscount = 403,
        amounttotalamount = 152887.15
        where journalclose_journalcloseid = 850679
    rollback tran
~~~~
# Centralizar CRE
~~~~sql
    USE [XML_CRE]
    GO

    DECLARE	@return_value int

    EXEC	@return_value = [dbo].[sp_InsFromOC_2640_ReporteVolumenes_v2019]
            @generarEncabezado = NULL

    SELECT	'Return Value' = @return_value

    GO
~~~~
# Operaciones desfazadas
## Reenviarlos
~~~~sql
    UPDATE [SRVOC].[opencard].[dbo].commtransactionintegration
    SET status = 'PENDING'
    WHERE creditcommercialtransaction_id  in ()
~~~~
## NOT NULL
~~~~sql
    SELECT        TOP (200) DTYPE, id, messageDate, failure, inputXML, processingMilliseconds, processingStatus, posDateTime, authorizationStatus, isNotification, terminal_id, creditcommercialtransaction_id, requesttype
    FROM            authorizationmessage
    WHERE (creditcommercialtransaction_id IN())
~~~~
## Revisar si se enviaron
~~~~sql
    select * from [SRVOC].[opencard].[dbo].commtransactionintegration 
    WHERE creditcommercialtransaction_id  in ()
~~~~
# Reporte 6:00 am
~~~~sql
    use Arcadia_cbos
    go

    declare @startDate date, @endDate date set @startDate ='2021-05-09' set @endDate ='2021-05-09'
    select convert(varchar(10),em.date,103) as Fecha,em.store as Centro_costos,
    em.product as id_articulo,coalesce(sm.quantity,0) as Existencia_inicial,coalesce(em.quantity,0) as medicion_final
    from getLastDayTankMovementForFA6AM(@startDate, @endDate) em 
    left join 
    getLastDayTankMovementForFA( dateadd(day, -2, @startDate), @endDate) sm on 
    em.product = sm.product and em.store = sm.store  and dateadd(day, -2, em.date) = sm.date 
    inner join gasstation gs on gs.posGasStationID= em.store left outer join getFuelReceptionsForFA(@startDate, @endDate) fr on
    fr.product = em.product and fr.store = em.store and fr.date = em.date 
    left outer join 
    getFuelDischargesForFA(@startDate, @endDate) fg on 
    fg.product = em.product and fg.store = em.store and fg.date = em.date 
    left outer join getFuelDepositForFA(@startDate, @endDate) fd on fd.product = em.product 
    and fd.store = em.store and fd.date = em.date left outer join getFuelEntryForFA(@startDate, @endDate) fe on
    fe.product = em.product and fe.store = em.store and fe.date = em.date 
    left outer join getFuelSalesForFA(@startDate, @endDate) fs on fs.product = em.product and
    fs.store = em.store and fs.date = em.date 
    left outer join 
    (select p.code as product, j.businessdate as date, g.posgasstationid as store, sum(l.salesquantity) as quantity,
    j.businessDate from transactionline l inner join transactionalevent e on e.eventid = l.storeevent_eventid
    inner join 
    journalclose j on e.journalClose_journalCloseID = j.journalCloseID
    inner join gasstation g on j.gasStation_gasStationID = g.gasStationID and e.gasStation_gasStationID = g.gasStationID
    inner join productdescription p ON l.soldable_soldableid = p.id where  l.dtype = 'FuelLine'
    and e.transactionaleventnature ='PumpTest' group by p.code, j.businessdate, g.posgasstationid)q 
    on q.store=em.store and q.businessDate =em.date and q.product= em.product order by 2,3
~~~~
# Mediciones
~~~~sql
    use Arcadia_cbos
    go

    SELECT distinct g.gasStationName as 'Estación sin medición',jer.id_pemex as 'IdPemex', g.posGasStationID 
    as 'Centro de Costos',jer.plaza, jer.campo, CONVERT(VARCHAR(10),q.fecha,103) as 'Último día con mediciones'
    FROM dbo.gasstation g left outer join dbo.journalclose j ON g.gasStationID = j.gasStation_gasStationID
    left outer join dbo.TankMovement t ON t.journalClose_journalCloseID = j.journalCloseID 
    left outer join dbo.tank tk ON t.tank_tankid = tk.tankid left outer join dbo.fuelproduct f 
        ON tk.fuelProduct_fuelProductID = f.fuelProductID
    LEFT OUTER JOIN dbo.fuelentry fe ON fe.journalclose_journalcloseid = j.journalCloseID 
        AND fe.tank_tankid= tk.tankid AND fe.gasstation_gasstationid= g.gasStationID AND fe.fuelproduct_fuelproductid= f.fuelProductID 
    LEFT OUTER JOIN arcadia_cas.dbo.Jerarquia jer ON jer.Centro_costos= g.posGasStationID 
    INNER JOIN (select  max(j.businessDate) fecha, g.posGasStationID FROM dbo.gasstation g
    left outer join dbo.journalclose j ON g.gasStationID = j.gasStation_gasStationID 
    left outer join dbo.TankMovement t ON t.journalClose_journalCloseID = j.journalCloseID
    left outer join dbo.tank tk ON t.tank_tankid = tk.tankid 
    left outer join dbo.fuelproduct f ON tk.fuelProduct_fuelProductID = f.fuelProductID 
    LEFT OUTER JOIN dbo.fuelentry fe 
        ON fe.journalclose_journalcloseid = j.journalCloseID AND fe.tank_tankid= tk.tankid AND fe.gasstation_gasstationid= g.gasStationID AND fe.fuelproduct_fuelproductid= f.fuelProductID
    LEFT OUTER JOIN arcadia_cas.dbo.Jerarquia jer 
        ON jer.Centro_costos= g.posGasStationID where (t.fuelProductVolume <> 0 and t.fuelProductVolume is not null)
    and j.shift= 2 group  by g.posGasStationID) q ON q.posGasStationID = g.posGasStationID 
    WHERE businessDate =DATEADD(day,-1, convert(date, getdate())) AND shift = 4 AND (t.fuelProductVolume= 0 or t.fuelProductVolume is null)

~~~~
# Reporte Irving
~~~~sql
    select distinct g.posGasStationID as 'Centro de costos', g.gasstationname Estacion,  frl.receptionreference as 'Id de Descarga',     
    fp.longDescription Producto   ,  CONVERT(VARCHAR(10), frj.businessDate, 103) as 'Fecha de Liquidacion',    
    CONVERT(VARCHAR(10), fr.fuelProductReceptionDate, 103) as 'Fecha de Captura',      
    CONVERT(VARCHAR(8), fr.fuelProductReceptionDate, 108) as 'Hora de Captura',      
    convert(varchar(10), ft1.invoicedate,103) 'Fecha Transporte',      
    convert(varchar(10), fr.documentDate,103) 'Fecha Documento',      
    CONVERT(VARCHAR(8), fr.documentDate, 108) as 'Hora de Documento',      
    convert(varchar(10), fr.auditRecordDate,103) 'Fecha De Registro',      
    CONVERT(VARCHAR(8), fr.auditRecordDate, 108) as 'Hora de Registro',      
    Case when ft1.invoicedate is not null then convert(varchar(10),     ft1.invoicedate,103) else convert(varchar(10), 
    fr.documentDate,103) end as 'Fecha de integracion',                                        
    coalesce(frl.realquantity,0) as 'Cantidad de descarga',coalesce(frl.quantity, 0) as 'Cantidad capturada',                                        
    fr.externalDocumentNumber as 'Folio Albarán',                                        
    case when ft1.invoicedate is null then 'no tiene descarga' else 'tiene descarga' end descarga,  
    s.posSupplierID as 'numero de proveedor transporte',s.supplierCompanyName as 'nombre de proveedor transporte',   
    s3.posSupplierID as 'numero de proveedor transporte 2',s3.supplierCompanyName as 'nombre de proveedor transporte 2',                           
    s2.posSupplierID as 'numero de proveedor',s2.supplierCompanyName as 'nombre de proveedor',   
    xs.code as 'Código del producto',  fr.employee_employeeid id_empleado,(Select firstname+' '+lastname from employee where employeeid=fr.employee_employeeid) as 'Nombre del empleado', 
    (select freightamount from fuelreceptiontransportline where fuelproductreceptionline_id= ft1.fuelproductreceptionline_id  and transportsupplier_id= ft1.transportsupplier_id) as 'Flete transportista 1',   
    (select freightamount from fuelreceptiontransportline where fuelproductreceptionline_id= ft2.fuelproductreceptionline_id  and transportsupplier_id= ft2.transportsupplier_id) as 'Flete transportista 2',   
    aj.campo, aj.plaza,   
    case when s.posSupplierID =  s3.posSupplierID or s.posSupplierID is  null then 'un transportista' else 'doble transportista'end  as 'Estatus transportista'                         
    from fuelproductreception fr                                        
    inner join journalclose frj on fr.journalClose_journalCloseID = frj.journalCloseID                                        
    inner join gasstation g on frj.gasStation_gasStationID = g.gasStationID                                        
    inner join fuelproductreceptionline frl on frl.merchandiseEvent_id = fr.id                                        
    inner join fuelproduct fp ON fp.fuelProductID = frl.fuelproduct_id                                        
    inner join productdescription pd ON pd.id = fp.fuelProductID                                        
    inner join XsysCode xs ON xs.entityId= pd.id and entityClass= 'ProductDescription' and xsys_id=4                                        
    INNER JOIN arcadia_cas.[dbo].[Jerarquia] aj on aj.Centro_costos=g.posGasStationID                                        
    left outer join (select fuelproductreceptionline_id fuelproductreceptionline_id,       
    min(transportsupplier_id) transportsupplier_id, invoicedate  from fuelreceptiontransportline       
    group by invoicedate, fuelproductreceptionline_id ) ft1 ON ft1.fuelproductreceptionline_id = frl.id      
    left outer join (select fuelproductreceptionline_id fuelproductreceptionline_id,       
    max(transportsupplier_id) transportsupplier_id, invoicedate  from fuelreceptiontransportline       
    group by invoicedate, fuelproductreceptionline_id ) ft2 ON ft2.fuelproductreceptionline_id = frl.id                                    
    left outer join supplier s ON ft1.transportsupplier_id= s.id  
    left outer join supplier s3 ON ft2.transportsupplier_id= s3.id                           
    left outer join supplier s2 ON fr.supplier_id = s2.id                                        
    where frj.businessDate between '2021-03-01' and '2021-04-26'
    --where frj.businessDate >= DATEADD(day,-60,GETDATE())         
    order by 1,2,3  
~~~~
# Para automatización
~~~~sql
    select distinct g.posGasStationID as 'centroCostos', g.gasstationname Estacion,  
    frl.receptionreference as 'idDescarga',fp.longDescription Producto   ,  
    CONVERT(VARCHAR(10), frj.businessDate, 103) as 'fechaLiquidacion',       
    CONVERT(VARCHAR(10), fr.fuelProductReceptionDate, 103) as 'fechaCaptura',         
    CONVERT(VARCHAR(8), fr.fuelProductReceptionDate, 108) as 'horaCaptura',         
    convert(varchar(10), ft1.invoicedate,103) 'fechaTransporte',         
    convert(varchar(10), fr.documentDate,103) 'fechaDocumento',         
    CONVERT(VARCHAR(8), fr.documentDate, 108) as 'horaDocumento',         
    convert(varchar(10), fr.auditRecordDate,103) 'fechaRegistro',         
    CONVERT(VARCHAR(8), fr.auditRecordDate, 108) as 'horaRegistro',        
    Case when ft1.invoicedate is not null then convert(varchar(10), ft1.invoicedate,103) else convert(varchar(10), fr.documentDate,103) end as 'fechaIntegracion',                                           
    coalesce(frl.realquantity,0) as 'cantidadDescarga',coalesce(frl.quantity, 0) as 'cantidadCapturada', fr.externalDocumentNumber as 'folioAlbaran',
    case when ft1.invoicedate is null then 'NoTieneDescarga' else 'TieneDescarga' end descarga,     
    s.posSupplierID as 'numeroProveedorTransporte',s.supplierCompanyName as 'nombreProveedorTransporte',
    s3.posSupplierID as 'numeroProveedorTransporte2',s3.supplierCompanyName as 'nombreProveedorTransporte2',
    s2.posSupplierID as 'numeroProveedor',s2.supplierCompanyName as 'nombreProveedor',      
    xs.code as 'codigoProducto',  
    fr.employee_employeeid id_empleado,(Select firstname+' '+lastname from employee where employeeid=fr.employee_employeeid) as 'nombreEmpleado',
    (select freightamount from fuelreceptiontransportline where fuelproductreceptionline_id= ft1.fuelproductreceptionline_id  and transportsupplier_id= ft1.transportsupplier_id) as 'fleteTransportista1',
    (select freightamount from fuelreceptiontransportline where fuelproductreceptionline_id= ft2.fuelproductreceptionline_id  and transportsupplier_id= ft2.transportsupplier_id) as 'fleteTransportista2',
    aj.campo, aj.plaza,      
    case when s.posSupplierID =  s3.posSupplierID or s.posSupplierID is  null then 'unTransportista' else 'dobleTransportista'end  as 'estatusTransportista'
    from fuelproductreception fr                                           
    inner join journalclose frj on fr.journalClose_journalCloseID = frj.journalCloseID                                           
    inner join gasstation g on frj.gasStation_gasStationID = g.gasStationID                                           
    inner join fuelproductreceptionline frl on frl.merchandiseEvent_id = fr.id                                           
    inner join fuelproduct fp ON fp.fuelProductID = frl.fuelproduct_id                                           
    inner join productdescription pd ON pd.id = fp.fuelProductID                                           
    inner join XsysCode xs ON xs.entityId= pd.id and entityClass= 'ProductDescription' and xsys_id=4                                           
    INNER JOIN arcadia_cas.[dbo].[Jerarquia] aj on aj.Centro_costos=g.posGasStationID                                           
    left outer join (select fuelproductreceptionline_id fuelproductreceptionline_id,          
                        min(transportsupplier_id) transportsupplier_id, invoicedate  from fuelreceptiontransportline          
                        group by invoicedate, fuelproductreceptionline_id ) ft1 ON ft1.fuelproductreceptionline_id = frl.id         
    left outer join (select fuelproductreceptionline_id fuelproductreceptionline_id,          
                    max(transportsupplier_id) transportsupplier_id, invoicedate  from fuelreceptiontransportline          
                    group by invoicedate, fuelproductreceptionline_id ) ft2 ON ft2.fuelproductreceptionline_id = frl.id                                       
    left outer join supplier s ON ft1.transportsupplier_id= s.id     
    left outer join supplier s3 ON ft2.transportsupplier_id= s3.id                              
    left outer join supplier s2 ON fr.supplier_id = s2.id                                           
    where  fr.externalDocumentNumber=  '485326'
    order by 5,7,1
~~~~
~~~~sql
    select top 5 id as 'aid' from merchandiseeventline where id in (106777388,107545554)
~~~~