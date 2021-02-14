public without sharing class Utils
{
    public static Organization orgInfo;

    public static Boolean IsSandbox()
    {
        if (orgInfo == null)
        {
            orgInfo = [SELECT IsSandbox, InstanceName, Name, OrganizationType FROM Organization LIMIT 1];
        }
        return orgInfo.IsSandBox;
    }

    public static List<Schema.PicklistEntry> ListPicklistValues(Schema.SObjectField field)
    {
        return field.getDescribe().getPicklistValues();
    }
}