trigger DocuSignStatus on dsfs__DocuSign_Status__c(after insert, after update)
{
    if (Trigger.isInsert)
    {
        DocuSignStatusTriggerHandler.AfterInsert(Trigger.new);
    }
    else // if (Trigger.isUpdate)
    {
        DocuSignStatusTriggerHandler.AfterUpdate(Trigger.old, Trigger.new);
    }
}