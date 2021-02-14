public without sharing class DocuSignStatusTriggerHandler
{
    public static void AfterInsert(List<dsfs__DocuSign_Status__c> newObjects)
    {
        UpdateRelatedOppStatus(newObjects, null);
    }

    public static void AfterUpdate(List<dsfs__DocuSign_Status__c> oldObjects, List<dsfs__DocuSign_Status__c> newObjects)
    {
        UpdateRelatedOppStatus(newObjects, oldObjects);
    }

    private static void UpdateRelatedOppStatus(List<dsfs__DocuSign_Status__c> newDocuSignStatuses, List<dsfs__DocuSign_Status__c> oldDocuSignStatuses)
    {
        System.debug('ENTERED DocuSignStatusHandler.UpdateRelatedOppStatus. ' + newDocuSignStatuses);

        Map<ID, String> oppIdToDocuSignStatus = new Map<ID, String>();
        for (Integer i = 0; i < newDocuSignStatuses.size(); i++)
        {
            dsfs__DocuSign_Status__c newStatus = newDocuSignStatuses[i];
            if (newStatus.dsfs__Opportunity__c == null ||
                oldDocuSignStatuses != null &&
                oldDocuSignStatuses[i].dsfs__Envelope_Status__c == newStatus.dsfs__Envelope_Status__c)
            {
                // An updated DocuSign Status with no change in envelope status should not trigger an opp update.
                continue;
            }

            oppIdToDocuSignStatus.put(newStatus.dsfs__Opportunity__c, newStatus.dsfs__Envelope_Status__c);
        }

        if (!oppIdToDocuSignStatus.isEmpty())
        {
            UpdateDocuSignOpps(oppIdToDocuSignStatus);
        }
        System.debug('LEAVING DocuSignStatusHandler.UpdateRelatedOppStatus.');
    }

    ///
    /// Future method to ensure no data loss.
    /// Processing the opportunity update asynchronously will guarantee that when an opp update failure occurs then the DocuSign status object will be created/updated.
    ///
    @future
    private static void UpdateDocuSignOpps(Map<ID, String> oppIdToDocuSignStatus)
    {
        System.debug('ENTERED DocuSignStatusHandler.UpdateDocuSignOpps. IDs: ' + oppIdToDocuSignStatus);
        Map<ID, Opportunity> opps = new Map<ID, Opportunity>(
        [
            SELECT Id, Change_Request__c, OwnerId, RecordTypeId
              FROM Opportunity opp
             WHERE IsWon = false
               AND Id IN :oppIdToDocuSignStatus.keySet()
        ]);

        List<Opportunity> oppsToUpdate = GetOpportunitiesToUpdate(opps.values(), oppIdToDocuSignStatus);
        if (!oppsToUpdate.isEmpty())
        {
            try
            {
                update oppsToUpdate;
            }
            catch (DmlException ex)
            {
                CreateErrorNotificationTaskForOppOwners(opps, ex);
            }
        }
    }

    private static List<Opportunity> GetOpportunitiesToUpdate(List<Opportunity> opps, Map<ID, String> oppIdToDocuSignStatus)
    {
        List<Opportunity> oppsToUpdate = new List<Opportunity>();
        for (Opportunity o :opps)
        {
            oppsToUpdate.add(o);

            String dsStatus = oppIdToDocuSignStatus.get(o.Id);

            if (dsStatus == 'Declined' ||
                dsStatus == 'Voided')
            {
                continue;
            }

            if (dsStatus != 'Completed')
            {
                o.StageName = 'DocuSign Pending';
                continue;
            }

            if (!o.Change_Request__c) // field will be populated from completed DocuSign through integration
            {
                o.StageName = OpportunityHelper.STAGE_CLOSED_WON;
                continue;
            }

            o.StageName = 'On Hold';
            o.NextStep = 'Update Address';
        }
        return oppsToUpdate;
    }

    private static void CreateErrorNotificationTaskForOppOwners(Map<ID, Opportunity> opps, DmlException ex)
    {
        List<Task> tasksToInsert = new List<Task>();
        for (Integer i = 0; i < ex.getNumDml(); i++)
        {
            Opportunity opp = opps.get(ex.getDmlId(i));
            ID ownerId = opp.OwnerId;
            tasksToInsert.add(new Task
            (
                ActivityDate = Date.today(),
                Description = 'A DocuSign status has been updated but an error was encountered attempting to update the related opportunity. ' +
                              'Please contact your administrator if you are unable to resolve this issue.' +
                              '\n\nError code: ' + ex.getDmlStatusCode(i) +
                              '\nError message: ' + ex.getDmlMessage(i).replace('<br/>', '\n'),
                IsReminderSet = true,
                OwnerId = ownerId,
                Priority = 'High',
                ReminderDateTime = DateTime.now().addHours(1),
                Status = 'In Progress',
                Subject = 'DocuSign Failed to Update Opportunity',
                Type = 'Other',
                WhatId = opp.Id
            ));
        }
        if (!tasksToInsert.isEmpty())
        {
            insert tasksToInsert;
        }
    }
}