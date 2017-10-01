﻿using Newtonsoft.Json;
using System.Management.Automation;

namespace psCheckPoint.Objects.Application
{
    /// <api cmd="add-application-site">New-CheckPointApplication</api>
    /// <summary>
    /// <para type="synopsis">Create new object.</para>
    /// <para type="description"></para>
    /// </summary>
    /// <example>
    ///   <code></code>
    /// </example>
    [Cmdlet(VerbsCommon.New, "CheckPointApplication")]
    [OutputType(typeof(CheckPointApplication))]
    public class NewCheckPointApplication : NewCheckPointCmdlet<CheckPointApplication>
    {
        public override string Command { get { return "add-application-site"; } }

        /// <summary>
        /// <para type="description">Collection of group identifiers.</para>
        /// </summary>
        [JsonProperty(PropertyName = "groups", DefaultValueHandling = DefaultValueHandling.Ignore)]
        [Parameter(ValueFromPipelineByPropertyName = true)]
        public string[] Groups
        {
            get { return _groups; }
            set { _groups = CreateArray(value); }
        }

        private string[] _groups;

        /// <summary>
        /// <para type="description">Each application is assigned to one primary category based on its most defining aspect.</para>
        /// </summary>
        [JsonProperty(PropertyName = "primary-category")]
        [Parameter(ValueFromPipelineByPropertyName = true, Mandatory = true)]
        public string PrimaryCategory { get; set; }

        /// <summary>
        /// <para type="description">URLs that determine this particular application.</para>
        /// </summary>
        [JsonProperty(PropertyName = "url-list")]
        [Parameter(ValueFromPipelineByPropertyName = true, Mandatory = true, ParameterSetName = "By URLs")]
        public string[] UrlList
        {
            get { return _urls; }
            set { _urls = CreateArray(value); }
        }

        private string[] _urls;

        /// <summary>
        /// <para type="description">Application signature generated by Signature Tool.</para>
        /// </summary>
        [JsonProperty(PropertyName = "application-signature")]
        [Parameter(ValueFromPipelineByPropertyName = true, Mandatory = true, ParameterSetName = "By Application Signature")]
        public string[] ApplicationSignature
        {
            get { return _applicationSignatures; }
            set { _applicationSignatures = CreateArray(value); }
        }

        private string[] _applicationSignatures;

        /// <summary>
        /// <para type="description">Used to configure or edit the additional categories of a custom application / site used in the Application and URL Filtering or Threat Prevention.</para>
        /// </summary>
        [JsonProperty(PropertyName = "additional-categories", DefaultValueHandling = DefaultValueHandling.Ignore)]
        [Parameter(ValueFromPipelineByPropertyName = true)]
        public string[] AdditionalCategories
        {
            get { return _additionalCategories; }
            set { _additionalCategories = CreateArray(value); }
        }

        private string[] _additionalCategories;

        /// <summary>
        /// <para type="description">A description for the application.</para>
        /// </summary>
        [JsonProperty(PropertyName = "description")]
        [Parameter(ValueFromPipelineByPropertyName = true)]
        public string Description { get; set; }

        /// <summary>
        /// <para type="description">States whether the URL is defined as a Regular Expression or not.</para>
        /// </summary>
        [JsonProperty(PropertyName = "urls-defined-as-regular-expression", DefaultValueHandling = DefaultValueHandling.Ignore)]
        [JsonConverter(typeof(SwitchJsonConverter))]
        [Parameter]
        public SwitchParameter UrlsDefinedAsRegularExpression { get; set; }
    }
}