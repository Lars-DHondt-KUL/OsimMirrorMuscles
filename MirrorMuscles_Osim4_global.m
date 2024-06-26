clear;clc
import org.opensim.modeling.*

modelPath = 'C:\Users\u0150099\Downloads\GF_OneLegged_30042024_R_test3_1.osim'; % full path to .osim 
modelNewPath = 'C:\Users\u0150099\Downloads\GF_OneLegged_30042024_R_test3_2.osim'; % leave blank to make new file in same directory as modelPath with "_Mirror" appended.
modelNewName = []; % leave blank to preserve name from old model
parameterFile = '';
saveParameters = false;
loadParameters = false;

defaultSymAxis = [1 1 -1];
midlineBodyList = {'pelvis'};


%%
if isempty(modelNewPath)
    modelNewPath = [strrep(modelPath,'.osim',''),'_Mirror.osim'];
end

if loadParameters
    if isempty(parameterFile)
        load([strrep(modelPath,'.osim',''),'_MirrorParameters.mat']);
    end
    % will have an option to overwrite input parameters above with values
    % from file.
end
if saveParameters
    savename = [strrep(modelPath,'.osim',''),'_MirrorParameters.mat'];
    save(savename,'modelPath','bodySymAxis','midlineBodyList','defaultSymAxis')
end

model = Model(modelPath);

if ~isempty(modelNewName)
    model.setName(modelNewName);
end
% Get the state
state = model.initSystem();
bodySet = model.getBodySet();

%% Duplicate and mirror wrapping objects
import org.opensim.modeling.*

newWrapObjects = struct();
nBodies = bodySet.getSize;
for ii = 0:nBodies-1
    disp(' ')
    body = Body().safeDownCast(bodySet.getPropertyByIndex(1).updValueAsObject(ii));
    bodyName = cell2mat(body.getName.string);
    
    isMidlineBody = false;
    [bodyName_l, bodyName_r] = mirrorName(bodyName);
    if any(strcmp(bodyName,midlineBodyList))
       isMidlineBody = true; 
       disp([bodyName,' identified as Midline Body'])
    elseif strcmpi(bodyName, bodyName_r)
        isMidlineBody = false;
        disp([bodyName,' identified as Rightside Body'])
    elseif strcmpi(bodyName, bodyName_l)
         disp([bodyName,' identified as Leftside Body'])
         continue % skip to the next iteration
    else
        warning([bodyName,' could not be identified as Midline, Right or Left',...
            newline,'Interpreting as midline body'])
        isMidlineBody = true;
    end
    wrapSet = body.updPropertyByName('WrapObjectSet');
    wrapSetObj = wrapSet.getValueAsObject(0);
    wrapSetArray = wrapSetObj.updPropertyByIndex(1);
    disp(['-- Finding wrap objects for ',bodyName])
    
    % Cannot get Array size apriori. Loop trough until it issues an error
    % to find array size
    working = true;
    i = 0;
    while working
        try
            wrapSetArray.getValueAsObject(i);
            i = i+1;
        catch
            working = false;
            break
        end  
    end
    nWrapObjects = i;
    disp([num2str(nWrapObjects),' wrap objects found'])
    
    if isMidlineBody
        bodyAttachName = bodyName;
        bodyAttach = body;
    else
        bodyAttachName = mirrorName(bodyName);
        bodyAttach = bodySet.get(bodyAttachName);
    end
    
    for i = 0:nWrapObjects-1
        wrapObj = wrapSetArray.getValueAsObject(i);
        wrapType = cell2mat(wrapObj.getConcreteClassName.string);
        wrapObj = org.opensim.modeling.(wrapType)().safeDownCast(wrapObj); % gets wrap object as derived class
        
        wrapObj2 = wrapObj.clone();% duplicate wrap object
        nameOld = wrapObj.getName.string;
        nameNew = mirrorName(nameOld{1}); % set as "left"
        wrapObj2.setName(nameNew);
        
        transOld = wrapObj.get_translation().string;
        transOldMat = str2num(transOld{1}(3:end-1));
        transOldMat_global = body.findStationLocationInGround(state,mat2Vec3(transOldMat)).getAsMat;
        mirror = defaultSymAxis;

        transNewMat_global = transOldMat_global.*mirror(:);
        transNewMat = model.getGround().findStationLocationInAnotherFrame(state,mat2Vec3(transNewMat_global),bodyAttach.findBaseFrame()).getAsMat;
        wrapObj2.set_translation(mat2Vec3(transNewMat));
        
        rotOld = wrapObj.get_xyz_body_rotation().string;
        rotOldMat = str2num(rotOld{1}(3:end-1));

        quadOld = cell2mat(wrapObj.get_quadrant.string);
        quadNew = quadOld;

        % rotation matrix of wrap in body
        rotmOld_wrap_body = eul2rotm(rotOldMat,'XYZ');
        % rotation matrix of body in global
        rotmOld_body_global = Mat33ToDouble(body.getTransformInGround(state).R().asMat33());
        % rotation matrix of wrap in global
        rotmOld_wrap_global = rotmOld_body_global*rotmOld_wrap_body;
        % Euler angles of wrap in global
        rotOld_wrap_global = rotm2eul(rotmOld_wrap_global,'XYZ');
        % Euler angles of mirrored wrap in global
        rot_wrap_global = rotOld_wrap_global.*(-mirror);

        % band-aid fix
        if mirror(3)==-1 && strcmp(quadNew,'z')
            rot_wrap_global(2) = rot_wrap_global(2) + pi;
            rot_wrap_global(3) = -rot_wrap_global(3);
        end

        % rotation matrix of mirrored wrap in global
        rotm_wrap_global = eul2rotm(rot_wrap_global,'XYZ');
        % rotation matrix of mirror body in global
        rotm_body_global = Mat33ToDouble(bodyAttach.getTransformInGround(state).R().asMat33());
        % rotation matrix of mirrored wrap in body
        rotm_wrap_body = rotm_body_global'*rotm_wrap_global;
        % Euler angles of mirrored wrap in body
        rot_wrap_body = rotm2eul(rotm_wrap_body,'XYZ');
        rotNewMat = rot_wrap_body;

        wrapObj2.set_xyz_body_rotation(mat2Vec3(rotNewMat));
        

        wrapObj2.set_quadrant(quadNew);
        
        bodyAttach.addWrapObject(wrapObj2)
        newWrapObjects.(nameNew) = wrapObj2; % save structure of new wrap objects to use later
    end
    model.initSystem(); 
end

%% iterate through muscles


nMuscles = model.getMuscles.getSize;
nForces = model.getForceSet.getSize;
for ii = 0:nMuscles-1
    forces = model.getForceSet();
    muscles = model.getMuscles();
    muscleRight = muscles.get(ii);
    forces.cloneAndAppend(muscleRight); % duplicate muscle and add to the force set.
    muscleClass = muscleRight.getConcreteClassName();
    switch true
        case strcmp(muscleClass, 'Millard2012EquilibriumMuscle')
            muscleLeft = ... % retrieve new muscle in matlab-safe version.
                Millard2012EquilibriumMuscle.safeDownCast(forces.get(model.getForceSet.getSize-1));
            muscleRight = ... % also retrieve right muscle in derived class
                Millard2012EquilibriumMuscle.safeDownCast(muscleRight);

        case strcmp(muscleClass, 'DeGrooteFregly2016Muscle')
            % can first use DeGrooteFregly2016Muscle.replaceMuscles(model)
            % https://simtk.org/api_docs/opensim/api_docs/classOpenSim_1_1DeGrooteFregly2016Muscle.html#af728fc5ada2e3813ba150cc127e80805
            muscleLeft = ... % retrieve new muscle in matlab-safe version.
                DeGrooteFregly2016Muscle.safeDownCast(forces.get(model.getForceSet.getSize-1));
            muscleRight = ... % also retrieve right muscle in derived class
                DeGrooteFregly2016Muscle.safeDownCast(muscleRight);

        otherwise
            error(["Support for muscles of class '%s' is not implemented."], muscleClass)
    end
    muscleoldname = char(muscleRight.getName());
    musclenewname = mirrorName(muscleoldname);
    muscleLeft.setName(musclenewname);
    disp(['---New muscle ',musclenewname,' cloned from ',muscleoldname,'---'])
    
    %%% Get the geometry path
    geomPath = muscleLeft.updGeometryPath();%muscle2.getPropertyByName('GeometryPath');
    pathPointSet = geomPath.getPathPointSet();
    nPP = pathPointSet.getSize;
    
    for i = 0:nPP-1
        pathPoint = geomPath.getPathPointSet().getPropertyByIndex(0).getValueAsObject(i);
        ppName = char(pathPoint.getName());
        ppBody = ... % gets the parent body and removes the affix '/bodyset/'
            strrep(cell2mat(pathPoint.getPropertyByName('socket_parent_frame').string),'/bodyset/','');
        ppLoc = cell2mat(pathPoint.getPropertyByName('location').string);
        
        mirror = defaultSymAxis;

        if any(strcmp(ppBody,midlineBodyList))
            ppNewBody = ppBody;
        else
            ppNewBody = mirrorName(ppBody);
        end
        ppLocMat = str2num(ppLoc(2:end-1));

        ppLocMat_global = bodySet.get(ppBody).findStationLocationInGround(state,mat2Vec3(ppLocMat)).getAsMat();

        ppNewLocMat_global = ppLocMat_global.*mirror(:); % flips the sign of one of the values
        ppNewLocMat = model.getGround().findStationLocationInAnotherFrame(state,mat2Vec3(ppNewLocMat_global),bodySet.get(ppNewBody).findBaseFrame()).getAsMat;
        ppNewName = ppName;
        [ppNewName_l, ppNewName_r] = mirrorName(ppName);
        if strcmpi(ppName,ppNewName_r)
            ppNewName = ppNewName_l;
        end
        muscleLeft.addNewPathPoint(ppNewName,bodySet.get(ppNewBody),mat2Vec3(ppNewLocMat))
        disp(['New path point ',ppNewName,' added to ',musclenewname])
        disp(['  Path point attached to body ',ppNewBody])
        disp(['  Location moved from ',ppLoc,' to ',mat2str(ppNewLocMat)])
        disp(' ')
    end
    %%% Delete original Path Points
    state = model.initSystem(); % reinitialize the state
    for i = 0:nPP-1
        geomPath.deletePathPoint(state,0);
    end
    %%% Add Path Wraps
    nWraps = geomPath.getWrapSet.getSize;
    wrapSet = geomPath.updWrapSet;
    for i = 0:nWraps-1
        pathWrap = PathWrap().safeDownCast(wrapSet.getPropertyByName('objects').getValueAsObject(i));
        pathWrapName = cell2mat(pathWrap.get_wrap_object.string);
        pathWrapNewName = mirrorName(pathWrapName);
        
        % duplicate wrap object
        wrapSet.cloneAndAppend(pathWrap);
        pathWrapNew = pathWrap().safeDownCast(wrapSet.getPropertyByName('objects').updValueAsObject(i+nWraps));
        pathWrapNew.set_wrap_object(pathWrapNewName);
        
        % get corresponding range from Right muscle (will not transfer over
        % to left muscle)
        pathWrapRight = PathWrap.safeDownCast(muscleRight.getGeometryPath().getWrapSet.getPropertyByName('objects').getValueAsObject(i));
        wrapRange(1) = pathWrapRight.get_range(0);
        wrapRange(2) = pathWrapRight.get_range(1);
        
        % set apropriate range for new wrap object on left muscle 
        pathWrapNew.set_range(0,wrapRange(1));
        pathWrapNew.set_range(1,wrapRange(2));
    end
    %%% Delete original Path Wraps
    state = model.initSystem();
    for i = 0:nWraps-1
        geomPath.deletePathWrap(state,0);
    end
end
%% Save the model to a file
model.initSystem(); % check model consistency
model.print(modelNewPath);
disp([modelNewPath,' printed'])
