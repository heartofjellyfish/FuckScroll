#!/usr/bin/env python3
"""Reproducible Xcode project generation. Python standard library only."""
from pathlib import Path
import hashlib, json, plistlib
ROOT = Path(__file__).resolve().parents[1]
objects = {}
def uid(value): return hashlib.sha1(value.encode()).hexdigest()[:24].upper()
def add(key, isa, **values):
    ident = uid(key)
    objects[ident] = dict(isa=isa, **values)
    return ident
def ref(path, kind):
    return add('file:'+path, 'PBXFileReference', lastKnownFileType=kind, path=path, sourceTree='<group>')
def plist(path, value):
    dest = ROOT / path
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_bytes(plistlib.dumps(value, sort_keys=False))
def config_list(key, settings):
    configs = []
    for name in ['Debug','Release']:
        configured = settings | {'SWIFT_OPTIMIZATION_LEVEL': '-Onone' if name=='Debug' else '-O'}
        if name=='Debug': configured['SWIFT_ACTIVE_COMPILATION_CONDITIONS']='DEBUG'
        configs.append(add(key+name,'XCBuildConfiguration',buildSettings=configured,name=name))
    return add(key+'configs','XCConfigurationList',buildConfigurations=configs,defaultConfigurationIsVisible=0,defaultConfigurationName='Release')
assets = ROOT / 'ScrollStopper/Resources/Assets.xcassets'
for image in ['DuckChill','DuckRage','DuckWalk','ShieldChill','ShieldRage']:
    metadata = assets / (image+'.imageset') / 'Contents.json'
    if not metadata.exists():
        metadata.write_text(json.dumps({'images':[{'filename':'duck.png','idiom':'universal'}],'info':{'author':'xcode','version':1}}))
(assets / 'Contents.json').write_text(json.dumps({'info':{'author':'xcode','version':1}}))
shared = sorted(str(p.relative_to(ROOT)) for p in (ROOT/'ScrollStopper/Shared').glob('*.swift'))
app = sorted(str(p.relative_to(ROOT)) for p in (ROOT/'ScrollStopper/App').glob('*.swift'))
target_specs = [
    ('ScrollStopper', 'com.heartofjellyfish.scrollstopper', app+shared, None, None),
    ('ActivityMonitor','com.heartofjellyfish.scrollstopper.monitor',['Extensions/ActivityMonitor/ActivityMonitor.swift']+shared,'com.apple.deviceactivity.monitor-extension','ActivityMonitor'),
    ('ShieldConfiguration','com.heartofjellyfish.scrollstopper.shield',['Extensions/ShieldConfiguration/ShieldConfiguration.swift']+shared,'com.apple.ManagedSettingsUI.shield-configuration-service','ShieldConfiguration'),
    ('ShieldAction','com.heartofjellyfish.scrollstopper.action',['Extensions/ShieldAction/ShieldAction.swift']+shared,'com.apple.ManagedSettings.shield-action-service','ShieldAction'),
]
files = {}
for _,_,sources,_,_ in target_specs:
    for source in sources: files[source] = ref(source,'sourcecode.swift')
assetref = ref('ScrollStopper/Resources/Assets.xcassets','folder.assetcatalog')
catalog = ref('ScrollStopper/Resources/Duck.xcstrings','text.json.xcstrings')
privacyref = ref('ScrollStopper/Resources/PrivacyInfo.xcprivacy','text.xml')
products = []
target_ids = []
extension_ids = []
common = {'DEVELOPMENT_TEAM':'47C4WT5UPR','SDKROOT':'iphoneos','IPHONEOS_DEPLOYMENT_TARGET':'17.4','SWIFT_VERSION':'5.0','TARGETED_DEVICE_FAMILY':'1','CODE_SIGN_STYLE':'Automatic','CURRENT_PROJECT_VERSION':'75','MARKETING_VERSION':'1.2','CLANG_ENABLE_MODULES':'YES','SWIFT_EMIT_LOC_STRINGS':'YES','ENABLE_USER_SCRIPT_SANDBOXING':'YES','SUPPORTED_PLATFORMS':'iphoneos iphonesimulator','SUPPORTS_MACCATALYST':'NO','SUPPORTS_MAC_DESIGNED_FOR_IPHONE_IPAD':'NO'}
for name,bundle,sources,ext,principal in target_specs:
    product = add(name+'product','PBXFileReference',explicitFileType='wrapper.app-extension' if ext else 'wrapper.application',includeInIndex=0,path=name+('.appex' if ext else '.app'),sourceTree='BUILT_PRODUCTS_DIR')
    products.append(product)
    builds=[add(name+source,'PBXBuildFile',fileRef=files[source]) for source in sources]
    source_phase=add(name+'sources','PBXSourcesBuildPhase',buildActionMask=2147483647,files=builds,runOnlyForDeploymentPostprocessing=0)
    resources=[]
    if name in ['ScrollStopper','ShieldConfiguration']:
        resources.append(add(name+'asset','PBXBuildFile',fileRef=assetref))
    resources.append(add(name+'strings','PBXBuildFile',fileRef=catalog))
    resources.append(add(name+'privacy','PBXBuildFile',fileRef=privacyref))
    resource_phase=add(name+'resources','PBXResourcesBuildPhase',buildActionMask=2147483647,files=resources,runOnlyForDeploymentPostprocessing=0)
    framework_phase=add(name+'frameworks','PBXFrameworksBuildPhase',buildActionMask=2147483647,files=[],runOnlyForDeploymentPostprocessing=0)
    info={'CFBundleDisplayName':'Scroll Stopper' if not ext else name,'CFBundleExecutable':'$(EXECUTABLE_NAME)','CFBundleIdentifier':'$(PRODUCT_BUNDLE_IDENTIFIER)','CFBundleInfoDictionaryVersion':'6.0','CFBundleName':'$(PRODUCT_NAME)','CFBundlePackageType':'XPC!' if ext else 'APPL','CFBundleShortVersionString':'$(MARKETING_VERSION)','CFBundleVersion':'$(CURRENT_PROJECT_VERSION)'}
    if ext: info['NSExtension']={'NSExtensionPointIdentifier':ext,'NSExtensionPrincipalClass':'$(PRODUCT_MODULE_NAME).'+principal}
    else:
        info.update({'LSRequiresIPhoneOS':True,'UILaunchScreen':{'UIColorName':'LaunchPaper'},'UIApplicationSceneManifest':{'UIApplicationSupportsMultipleScenes':False},'UISupportedInterfaceOrientations':['UIInterfaceOrientationPortrait'],'CFBundleURLTypes':[{'CFBundleURLSchemes':['scrollstopper'],'CFBundleURLName':bundle}]})
    plist('Config/'+name+'-Info.plist',info)
    plist('Config/'+name+'.entitlements',{'com.apple.developer.family-controls':True,'com.apple.security.application-groups':['group.com.heartofjellyfish.scrollstopper']})
    settings=common|{'PRODUCT_BUNDLE_IDENTIFIER':bundle,'PRODUCT_NAME':'$(TARGET_NAME)','INFOPLIST_FILE':'Config/'+name+'-Info.plist','CODE_SIGN_ENTITLEMENTS':'Config/'+name+'.entitlements','GENERATE_INFOPLIST_FILE':'NO'}
    if ext: settings|={'APPLICATION_EXTENSION_API_ONLY':'YES','SKIP_INSTALL':'YES'}
    else: settings['ASSETCATALOG_COMPILER_APPICON_NAME']='AppIcon'
    target=add(name+'target','PBXNativeTarget',buildConfigurationList=config_list(name,settings),buildPhases=[source_phase,framework_phase,resource_phase],buildRules=[],dependencies=[],name=name,productName=name,productReference=product,productType='com.apple.product-type.app-extension' if ext else 'com.apple.product-type.application')
    target_ids.append(target)
    if ext: extension_ids.append((target,product,name))
embed=[]
deps=[]
for target,product,name in extension_ids:
    embed.append(add(name+'embed','PBXBuildFile',fileRef=product,settings={'ATTRIBUTES':['RemoveHeadersOnCopy']}))
    proxy=add(name+'proxy','PBXContainerItemProxy',containerPortal=uid('project'),proxyType=1,remoteGlobalIDString=target,remoteInfo=name)
    deps.append(add(name+'dependency','PBXTargetDependency',target=target,targetProxy=proxy))
objects[target_ids[0]]['dependencies']=deps
objects[target_ids[0]]['buildPhases'].append(add('embed','PBXCopyFilesBuildPhase',buildActionMask=2147483647,dstPath='',dstSubfolderSpec=13,files=embed,name='Embed App Extensions',runOnlyForDeploymentPostprocessing=0))
# Native end-to-end UI tests run without Screen Time permission. Explicit
# rehearsal arguments inject only in-memory fixtures, never real shielding.
test_sources = sorted(str(p.relative_to(ROOT)) for p in (ROOT/'Tests/UI').glob('*.swift'))
for source in test_sources: files[source] = ref(source, 'sourcecode.swift')
test_product = add('uitests.product','PBXFileReference',explicitFileType='wrapper.cfbundle',includeInIndex=0,path='ScrollStopperUITests.xctest',sourceTree='BUILT_PRODUCTS_DIR')
products.append(test_product)
test_phase=add('uitests.sources','PBXSourcesBuildPhase',buildActionMask=2147483647,files=[add('uitests.'+source,'PBXBuildFile',fileRef=files[source]) for source in test_sources],runOnlyForDeploymentPostprocessing=0)
test_proxy=add('uitests.proxy','PBXContainerItemProxy',containerPortal=uid('project'),proxyType=1,remoteGlobalIDString=target_ids[0],remoteInfo='ScrollStopper')
test_dep=add('uitests.dependency','PBXTargetDependency',target=target_ids[0],targetProxy=test_proxy)
test_settings=common|{'PRODUCT_BUNDLE_IDENTIFIER':'com.heartofjellyfish.scrollstopper.uitests','PRODUCT_NAME':'$(TARGET_NAME)','GENERATE_INFOPLIST_FILE':'YES','TEST_TARGET_NAME':'ScrollStopper'}
test_target=add('uitests.target','PBXNativeTarget',buildConfigurationList=config_list('uitests',test_settings),buildPhases=[test_phase],buildRules=[],dependencies=[test_dep],name='ScrollStopperUITests',productName='ScrollStopperUITests',productReference=test_product,productType='com.apple.product-type.bundle.ui-testing')
target_ids.append(test_target)
product_group=add('products','PBXGroup',children=products,name='Products',sourceTree='<group>')
main_group=add('main','PBXGroup',children=list(files.values())+[assetref,catalog,privacyref,product_group],sourceTree='<group>')
add('project','PBXProject',attributes={'LastSwiftUpdateCheck':'2660','LastUpgradeCheck':'2660','BuildIndependentTargetsInParallel':'YES'},buildConfigurationList=config_list('project',{'CLANG_ENABLE_MODULES':'YES','DEBUG_INFORMATION_FORMAT':'dwarf-with-dsym'}),compatibilityVersion='Xcode 14.0',developmentRegion='en',hasScannedForEncodings=0,knownRegions=['en','zh-Hans','zh-Hant','es','fr','de','it','ja','ko','pt-BR','Base'],mainGroup=main_group,productRefGroup=product_group,projectDirPath='',projectRoot='',targets=target_ids)
def serialize(value, indent=0):
    if isinstance(value, dict): return '{\n'+''.join('\t'*(indent+1)+json.dumps(str(k))+' = '+serialize(v,indent+1)+';\n' for k,v in value.items())+'\t'*indent+'}'
    if isinstance(value,list): return '( '+', '.join(serialize(v,indent) for v in value)+' )'
    if isinstance(value,int): return str(value)
    return json.dumps(value)
project=ROOT/'ScrollStopper.xcodeproj'
project.mkdir(exist_ok=True)
(project/'project.pbxproj').write_text('// !$*UTF8*$!\n'+serialize({'archiveVersion':1,'classes':{},'objectVersion':56,'objects':objects,'rootObject':uid('project')}))
scheme=project/'xcshareddata/xcschemes'
scheme.mkdir(parents=True,exist_ok=True)
refxml=f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{target_ids[0]}" BuildableName="ScrollStopper.app" BlueprintName="ScrollStopper" ReferencedContainer="container:ScrollStopper.xcodeproj"/>'
(scheme/'ScrollStopper.xcscheme').write_text(f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="2660" version="1.3"><BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">{refxml}</BuildActionEntry></BuildActionEntries></BuildAction><TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES"><Testables><TestableReference skipped="NO"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{test_target}" BuildableName="ScrollStopperUITests.xctest" BlueprintName="ScrollStopperUITests" ReferencedContainer="container:ScrollStopper.xcodeproj"/></TestableReference></Testables></TestAction><LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0">{refxml}</BuildableProductRunnable></LaunchAction><ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">{refxml}</BuildableProductRunnable></ProfileAction><AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/></Scheme>''')
print('Generated ScrollStopper.xcodeproj (app + 3 Screen Time extensions)')
