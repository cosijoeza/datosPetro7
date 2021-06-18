    use Arcadia_cbos
    GO

  --begin tran
        update journalclosenotification
        set operationscount = 159,
        amounttotalamount = 80112.78
        where journalclose_journalcloseid = 873548
    --rollback tran