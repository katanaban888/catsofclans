#!/usr/bin/env python3
"""Генератор Xcode-проекта CatClans.xcodeproj.

Один app-таргет «CatClans» (iOS 15+) включает:
  - Sources/CatClansKit/**.swift  (игровое ядро)
  - CatClansApp/**.swift          (SwiftUI-интерфейс)
Информационный plist: CatClansApp/Info.plist.

Запуск:  python3 Scripts/generate_xcode_project.py
Проект пишется рядом с корнем репозитория: CatClans.xcodeproj/project.pbxproj
"""
import hashlib
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

APP_NAME = "CatClans"
BUNDLE_ID = "com.katanaban.catclans"
IPHONEOS_TARGET = "15.0"

KIT_DIR = os.path.join(ROOT, "Sources", "CatClansKit")
APP_DIR = os.path.join(ROOT, "CatClansApp")
PLIST = os.path.join("CatClansApp", "Info.plist")


def pid(key: str) -> str:
    """Детерминированный 24-символьный pbxproj-идентификатор."""
    return hashlib.sha1(key.encode("utf-8")).hexdigest()[:24].upper()


def collect(dirpath: str) -> list:
    out = []
    for base, _, files in os.walk(dirpath):
        for f in sorted(files):
            if f.endswith(".swift"):
                full = os.path.join(base, f)
                out.append(os.path.relpath(full, dirpath).replace(os.sep, "/"))
    return sorted(out)


def collect_asset_catalogs(dirpath: str) -> list:
    """Находит *.xcassets внутри каталога приложения."""
    out = []
    for base, dirs, _ in os.walk(dirpath):
        for d in sorted(dirs):
            if d.endswith(".xcassets"):
                full = os.path.join(base, d)
                out.append(os.path.relpath(full, dirpath).replace(os.sep, "/"))
    return sorted(out)


def main() -> None:
    kit_files = collect(KIT_DIR)
    app_files = [f for f in collect(APP_DIR)]
    asset_cats = collect_asset_catalogs(APP_DIR)
    if not kit_files or not app_files:
        print("Ой: не нашли swift-файки", file=sys.stderr)
        sys.exit(1)

    # ── ID ──
    id_main = pid("obj:main-group")
    id_src_group = pid("obj:group-sources")
    id_kit_group = pid("obj:group-kit")
    id_app_group = pid("obj:group-app")
    id_prod_group = pid("obj:group-products")
    id_app_ref = pid("ref:" + APP_NAME + ".app")
    id_target = pid("target:app")
    id_project = pid("project:catclans")
    id_src_phase = pid("phase:sources")
    id_fw_phase = pid("phase:frameworks")
    id_res_phase = pid("phase:resources")
    id_proj_cfg_list = pid("cfglist:project")
    id_tgt_cfg_list = pid("cfglist:target")
    id_proj_dbg = pid("cfg:project:debug")
    id_proj_rel = pid("cfg:project:release")
    id_tgt_dbg = pid("cfg:target:debug")
    id_tgt_rel = pid("cfg:target:release")

    def file_id(rel: str) -> str:
        return pid("file:" + rel)

    def build_id(rel: str) -> str:
        return pid("build:" + rel)

    build_files = []
    for f in kit_files:
        build_files.append((f, build_id("kit/" + f), file_id("kit/" + f), "kit/" + f))
    for f in app_files:
        build_files.append((f, build_id("app/" + f), file_id("app/" + f), "app/" + f))
    asset_entries = []
    for a in asset_cats:
        asset_entries.append((a, build_id("asset/" + a), file_id("asset/" + a)))
    plist_file_id = pid("file:" + PLIST)

    L = []
    L.append("// !$*UTF8*$!")
    L.append("{")
    L.append("\tarchiveVersion = 1;")
    L.append("\tclasses = {")
    L.append("\t};")
    L.append("\tobjectVersion = 56;")
    L.append("\tobjects = {")
    L.append("")

    # ── PBXBuildFile ──
    L.append("/* Begin PBXBuildFile section */")
    for f, bid, fid, key in build_files:
        L.append(f"\t\t{bid} /* {f} in Sources */ = {{isa = PBXBuildFile; fileRef = {fid} /* {f} */; }};")
    for a, bid, fid in asset_entries:
        L.append(f"\t\t{bid} /* {a} in Resources */ = {{isa = PBXBuildFile; fileRef = {fid} /* {a} */; }};")
    L.append("/* End PBXBuildFile section */")
    L.append("")

    # ── PBXFileReference ──
    L.append("/* Begin PBXFileReference section */")
    for f, bid, fid, key in build_files:
        L.append(f"\t\t{fid} /* {f} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {f}; sourceTree = \"<group>\"; }};")
    for a, bid, fid in asset_entries:
        L.append(f"\t\t{fid} /* {a} */ = {{isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; path = {a}; sourceTree = \"<group>\"; }};")
    L.append(f"\t\t{plist_file_id} /* Info.plist */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = Info.plist; sourceTree = \"<group>\"; }};")
    L.append(f"\t\t{id_app_ref} /* {APP_NAME}.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = {APP_NAME}.app; sourceTree = BUILT_PRODUCTS_DIR; }};")
    L.append("/* End PBXFileReference section */")
    L.append("")

    # ── PBXFrameworksBuildPhase ──
    L.append("/* Begin PBXFrameworksBuildPhase section */")
    L.append(f"\t\t{id_fw_phase} /* Frameworks */ = {{")
    L.append("\t\t\tisa = PBXFrameworksBuildPhase;")
    L.append("\t\t\tbuildActionMask = 2147483647;")
    L.append("\t\t\tfiles = (")
    L.append("\t\t\t);")
    L.append("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    L.append("\t\t};")
    L.append("/* End PBXFrameworksBuildPhase section */")
    L.append("")

    # ── PBXResourcesBuildPhase ──
    L.append("/* Begin PBXResourcesBuildPhase section */")
    L.append(f"\t\t{id_res_phase} /* Resources */ = {{")
    L.append("\t\t\tisa = PBXResourcesBuildPhase;")
    L.append("\t\t\tbuildActionMask = 2147483647;")
    L.append("\t\t\tfiles = (")
    for a, bid, fid in asset_entries:
        L.append(f"\t\t\t\t{bid} /* {a} in Resources */,")
    L.append("\t\t\t);")
    L.append("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    L.append("\t\t};")
    L.append("/* End PBXResourcesBuildPhase section */")
    L.append("")

    # ── PBXGroup ──
    L.append("/* Begin PBXGroup section */")
    L.append(f"\t\t{id_main} = {{")
    L.append("\t\t\tisa = PBXGroup;")
    L.append("\t\t\tchildren = (")
    L.append(f"\t\t\t\t{id_src_group} /* Sources */,")
    L.append(f"\t\t\t\t{id_app_group} /* {APP_NAME}App */,")
    L.append(f"\t\t\t\t{id_prod_group} /* Products */,")
    L.append("\t\t\t);")
    L.append("\t\t\tsourceTree = \"<group>\";")
    L.append("\t\t};")

    kit_children = "\n".join(
        f"\t\t\t\t{file_id('kit/' + f)} /* {f} */," for f in kit_files
    )
    L.append(f"\t\t{id_kit_group} /* CatClansKit */ = {{")
    L.append("\t\t\tisa = PBXGroup;")
    L.append("\t\t\tchildren = (")
    L.append(kit_children)
    L.append("\t\t\t);")
    L.append("\t\t\tpath = CatClansKit;")
    L.append("\t\t\tsourceTree = \"<group>\";")
    L.append("\t\t};")

    app_children_lines = [f"\t\t\t\t{file_id('app/' + f)} /* {f} */," for f in app_files]
    app_children_lines += [f"\t\t\t\t{fid} /* {a} */," for a, bid, fid in asset_entries]
    app_children = "\n".join(app_children_lines)
    L.append(f"\t\t{id_app_group} /* {APP_NAME}App */ = {{")
    L.append("\t\t\tisa = PBXGroup;")
    L.append("\t\t\tchildren = (")
    L.append(app_children)
    L.append(f"\t\t\t\t{plist_file_id} /* Info.plist */,")
    L.append("\t\t\t);")
    L.append(f"\t\t\tpath = {APP_NAME}App;")
    L.append("\t\t\tsourceTree = \"<group>\";")
    L.append("\t\t};")

    L.append(f"\t\t{id_src_group} /* Sources */ = {{")
    L.append("\t\t\tisa = PBXGroup;")
    L.append("\t\t\tchildren = (")
    L.append(f"\t\t\t\t{id_kit_group} /* CatClansKit */,")
    L.append("\t\t\t);")
    L.append("\t\t\tpath = Sources;")
    L.append("\t\t\tsourceTree = \"<group>\";")
    L.append("\t\t};")

    L.append(f"\t\t{id_prod_group} /* Products */ = {{")
    L.append("\t\t\tisa = PBXGroup;")
    L.append("\t\t\tchildren = (")
    L.append(f"\t\t\t\t{id_app_ref} /* {APP_NAME}.app */,")
    L.append("\t\t\t);")
    L.append("\t\t\tname = Products;")
    L.append("\t\t\tsourceTree = \"<group>\";")
    L.append("\t\t};")
    L.append("/* End PBXGroup section */")
    L.append("")

    # ── PBXNativeTarget ──
    L.append("/* Begin PBXNativeTarget section */")
    L.append(f"\t\t{id_target} /* {APP_NAME} */ = {{")
    L.append("\t\t\tisa = PBXNativeTarget;")
    L.append(f"\t\t\tbuildConfigurationList = {id_tgt_cfg_list} /* Build configuration list for PBXNativeTarget \"{APP_NAME}\" */;")
    L.append("\t\t\tbuildPhases = (")
    L.append(f"\t\t\t\t{id_src_phase} /* Sources */,")
    L.append(f"\t\t\t\t{id_fw_phase} /* Frameworks */,")
    L.append(f"\t\t\t\t{id_res_phase} /* Resources */,")
    L.append("\t\t\t);")
    L.append("\t\t\tbuildRules = (")
    L.append("\t\t\t);")
    L.append("\t\t\tdependencies = (")
    L.append("\t\t\t);")
    L.append(f"\t\t\tname = {APP_NAME};")
    L.append(f"\t\t\tproductName = {APP_NAME};")
    L.append(f"\t\t\tproductReference = {id_app_ref} /* {APP_NAME}.app */;")
    L.append("\t\t\tproductType = \"com.apple.product-type.application\";")
    L.append("\t\t};")
    L.append("/* End PBXNativeTarget section */")
    L.append("")

    # ── PBXProject ──
    L.append("/* Begin PBXProject section */")
    L.append(f"\t\t{id_project} /* Project object */ = {{")
    L.append("\t\t\tisa = PBXProject;")
    L.append("\t\t\tattributes = {")
    L.append("\t\t\t\tBuildIndependentTargetsInParallel = 1;")
    L.append("\t\t\t\tLastSwiftUpdateCheck = 1500;")
    L.append("\t\t\t\tLastUpgradeCheck = 1500;")
    L.append("\t\t\t\tTargetAttributes = {")
    L.append(f"\t\t\t\t\t{id_target} = {{")
    L.append("\t\t\t\t\t\tCreatedOnToolsVersion = 15.0;")
    L.append("\t\t\t\t\t};")
    L.append("\t\t\t\t};")
    L.append("\t\t\t};")
    L.append(f"\t\t\tbuildConfigurationList = {id_proj_cfg_list} /* Build configuration list for PBXProject \"{APP_NAME}\" */;")
    L.append("\t\t\tcompatibilityVersion = \"Xcode 14.0\";")
    L.append("\t\t\tdevelopmentRegion = en;")
    L.append("\t\t\thasScannedForEncodings = 0;")
    L.append("\t\t\tknownRegions = (")
    L.append("\t\t\t\ten,")
    L.append("\t\t\t\tBase,")
    L.append("\t\t\t\tru,")
    L.append("\t\t\t);")
    L.append(f"\t\t\tmainGroup = {id_main};")
    L.append(f"\t\t\tproductRefGroup = {id_prod_group} /* Products */;")
    L.append("\t\t\tprojectDirPath = \"\";")
    L.append("\t\t\tprojectRoot = \"\";")
    L.append("\t\t\ttargets = (")
    L.append(f"\t\t\t\t{id_target} /* {APP_NAME} */,")
    L.append("\t\t\t);")
    L.append("\t\t};")
    L.append("/* End PBXProject section */")
    L.append("")

    # ── PBXSourcesBuildPhase ──
    L.append("/* Begin PBXSourcesBuildPhase section */")
    L.append(f"\t\t{id_src_phase} /* Sources */ = {{")
    L.append("\t\t\tisa = PBXSourcesBuildPhase;")
    L.append("\t\t\tbuildActionMask = 2147483647;")
    L.append("\t\t\tfiles = (")
    for f, bid, fid, key in build_files:
        L.append(f"\t\t\t\t{bid} /* {f} in Sources */,")
    L.append("\t\t\t);")
    L.append("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    L.append("\t\t};")
    L.append("/* End PBXSourcesBuildPhase section */")
    L.append("")

    # ── XCBuildConfiguration ──
    L.append("/* Begin XCBuildConfiguration section */")

    common_proj = [
        ("ALWAYS_SEARCH_USER_PATHS", "NO"),
        ("CLANG_ANALYZER_NONNULL", "YES"),
        ("CLANG_ENABLE_MODULES", "YES"),
        ("CLANG_ENABLE_OBJC_ARC", "YES"),
        ("CLANG_WARN_BOOL_CONVERSION", "YES"),
        ("CLANG_WARN_CONSTANT_CONVERSION", "YES"),
        ("CLANG_WARN_INT_CONVERSION", "YES"),
        ("CLANG_WARN_NULL_DUPLICATE", "YES"),
        ("CLANG_WARN_UNREACHABLE_CODE", "YES"),
        ("COPY_PHASE_STRIP", "NO"),
        ("ENABLE_STRICT_OBJC_MSGSEND", "YES"),
        ("GCC_C_LANGUAGE_STANDARD", "gnu11"),
        ("GCC_NO_COMMON_BLOCKS", "YES"),
        ("IPHONEOS_DEPLOYMENT_TARGET", IPHONEOS_TARGET),
        ("MTL_FAST_MATH", "YES"),
        ("SDKROOT", "iphoneos"),
    ]

    def emit_cfg(cid: str, name: str, entries: list, extra_first: list = None) -> None:
        L.append(f"\t\t{cid} /* {name} */ = {{")
        L.append("\t\t\tisa = XCBuildConfiguration;")
        L.append("\t\t\tbuildSettings = {")
        for e in (extra_first or []):
            L.append(f"\t\t\t\t{e[0]} = {e[1]};")
        for k, v in entries:
            L.append(f"\t\t\t\t{k} = {v};")
        L.append("\t\t\t};")
        L.append(f"\t\t\tname = {name};")
        L.append("\t\t};")

    emit_cfg(id_proj_dbg, "Debug", common_proj, extra_first=[
        ("DEBUG_INFORMATION_FORMAT", "dwarf"),
        ("ENABLE_TESTABILITY", "YES"),
        ("GCC_DYNAMIC_NO_PIC", "NO"),
        ("GCC_OPTIMIZATION_LEVEL", "0"),
        ("GCC_PREPROCESSOR_DEFINITIONS", "( \"DEBUG=1\", \"$(inherited)\", )"),
        ("MTL_ENABLE_DEBUG_INFO", "INCLUDE_SOURCE"),
        ("ONLY_ACTIVE_ARCH", "YES"),
        ("SWIFT_ACTIVE_COMPILATION_CONDITIONS", "DEBUG"),
        ("SWIFT_OPTIMIZATION_LEVEL", "\"-Onone\""),
        ("VALIDATE_PRODUCT", "NO"),
    ])
    emit_cfg(id_proj_rel, "Release", common_proj, extra_first=[
        ("DEBUG_INFORMATION_FORMAT", "\"dwarf-with-dsym\""),
        ("ENABLE_NS_ASSERTIONS", "NO"),
        ("MTL_ENABLE_DEBUG_INFO", "NO"),
        ("SWIFT_COMPILATION_MODE", "wholesmodule"),
        ("SWIFT_OPTIMIZATION_LEVEL", "\"-O\""),
        ("VALIDATE_PRODUCT", "YES"),
    ])

    target_common = [
        ("CODE_SIGN_STYLE", "Automatic"),
        ("CURRENT_PROJECT_VERSION", "1"),
        ("GENERATE_INFOPLIST_FILE", "NO"),
        ("INFOPLIST_FILE", "CatClansApp/Info.plist"),
        ("LD_RUNPATH_SEARCH_PATHS", "( \"$(inherited)\", \"@executable_path/Frameworks\", )"),
        ("MARKETING_VERSION", "0.1.0"),
        ("PRODUCT_BUNDLE_IDENTIFIER", BUNDLE_ID),
        ("PRODUCT_NAME", "\"$(TARGET_NAME)\""),
        ("SWIFT_EMIT_LOC_STRINGS", "YES"),
        ("SWIFT_VERSION", "5.0"),
        ("TARGETED_DEVICE_FAMILY", "\"1,2\""),
    ]
    emit_cfg(id_tgt_dbg, "Debug", target_common)
    emit_cfg(id_tgt_rel, "Release", target_common)
    L.append("/* End XCBuildConfiguration section */")
    L.append("")

    # ── XCConfigurationList ──
    L.append("/* Begin XCConfigurationList section */")
    L.append(f"\t\t{id_proj_cfg_list} /* Build configuration list for PBXProject \"{APP_NAME}\" */ = {{")
    L.append("\t\t\tisa = XCConfigurationList;")
    L.append("\t\t\tbuildConfigurations = (")
    L.append(f"\t\t\t\t{id_proj_dbg} /* Debug */,")
    L.append(f"\t\t\t\t{id_proj_rel} /* Release */,")
    L.append("\t\t\t);")
    L.append("\t\t\tdefaultConfigurationIsVisible = 0;")
    L.append("\t\t\tdefaultConfigurationName = Release;")
    L.append("\t\t};")
    L.append(f"\t\t{id_tgt_cfg_list} /* Build configuration list for PBXNativeTarget \"{APP_NAME}\" */ = {{")
    L.append("\t\t\tisa = XCConfigurationList;")
    L.append("\t\t\tbuildConfigurations = (")
    L.append(f"\t\t\t\t{id_tgt_dbg} /* Debug */,")
    L.append(f"\t\t\t\t{id_tgt_rel} /* Release */,")
    L.append("\t\t\t);")
    L.append("\t\t\tdefaultConfigurationIsVisible = 0;")
    L.append("\t\t\tdefaultConfigurationName = Release;")
    L.append("\t\t};")
    L.append("/* End XCConfigurationList section */")
    L.append("")

    L.append("\t};")
    L.append(f"\trootObject = {id_project} /* Project object */;")
    L.append("}")

    out_dir = os.path.join(ROOT, APP_NAME + ".xcodeproj")
    os.makedirs(out_dir, exist_ok=True)
    out_path = os.path.join(out_dir, "project.pbxproj")
    with open(out_path, "w", encoding="utf-8") as fh:
        fh.write("\n".join(L) + "\n")

    # Базовая самопроверка: скобки и скоупы сбалансированы.
    text = "\n".join(L)
    assert text.count("{") == text.count("}"), "несбалансированы {}"
    assert text.count("(") == text.count(")"), "несбалансированы ()"
    print(f"OK: {os.path.relpath(out_path, ROOT)}")
    print(f"   файлов в таргете: {len(build_files)} (kit: {len(kit_files)}, app: {len(app_files)})")


if __name__ == "__main__":
    main()
